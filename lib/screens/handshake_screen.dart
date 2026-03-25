import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class HandshakeScreen extends StatefulWidget {
  final String rentalId;
  final Map<String, dynamic> rentalData;
  final bool isLender;
  final String actionType; // 'pickup' OR 'return'

  const HandshakeScreen({
    super.key,
    required this.rentalId,
    required this.rentalData,
    required this.isLender,
    required this.actionType,
  });

  @override
  State<HandshakeScreen> createState() => _HandshakeScreenState();
}

class _HandshakeScreenState extends State<HandshakeScreen> {
  final Strategy strategy = Strategy.P2P_POINT_TO_POINT;
  String statusText = "Ready to connect...";
  bool isProcessing = false;
  bool _isUsingQR = false;

  StreamSubscription<DocumentSnapshot>? _rentalSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listenForLenderUpdate();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.camera,
      Permission.nearbyWifiDevices,
    ].request();
  }

  // 📡 THE TELEPATHY: Borrower watches the DB to know when the Owner accepted the token!
  void _listenForLenderUpdate() {
    _rentalSubscription = FirebaseFirestore.instance
        .collection('rentals')
        .doc(widget.rentalId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        String currentStatus = (snapshot.data()?['status'] ?? '').toString().toLowerCase();

        if (!widget.isLender) {
          if (widget.actionType == 'pickup' && currentStatus == 'active') {
            _finishHandshakeAndPop("Pickup Confirmed! 🛠️");
          }
          // 🚀 IF RETURNED: Borrower is instantly hit with the compulsory review!
          else if (widget.actionType == 'return' &&
              (currentStatus.contains('return') || currentStatus.contains('complet'))) {
            _triggerCompulsoryReview();
          }
        }
      }
    });
  }

  // 🎉 FIRES ON PICKUP SUCCESS
  void _finishHandshakeAndPop(String message) {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      statusText = message;
    });

    _cleanupConnections();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  // ⭐ FIRES ON RETURN SUCCESS: Traps them in the Review Dialog
  void _triggerCompulsoryReview() {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      statusText = "Return Verified! Please leave a review.";
    });

    _cleanupConnections();
    _showCompulsoryReviewDialog();
  }

  void _cleanupConnections() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
  }

  @override
  void dispose() {
    _rentalSubscription?.cancel();
    _cleanupConnections();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 📡 BLE ROLE 1: LENDER (ADVERTISES)
  // ----------------------------------------------------------------
  Future<void> _startAdvertising() async {
    setState(() => statusText = "Broadcasting for Borrower...");
    try {
      bool a = await Nearby().startAdvertising(
        widget.rentalId,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() => statusText = "Connected! Waiting for Borrower's token...");
          }
        },
        onDisconnected: (id) => setState(() => statusText = "Disconnected."),
      );
      if (!a) setState(() => statusText = "Failed to broadcast.");
    } catch (e) {
      setState(() => statusText = "Error: $e");
    }
  }

  // ----------------------------------------------------------------
  // 🔍 BLE ROLE 2: BORROWER (DISCOVERS)
  // ----------------------------------------------------------------
  Future<void> _startDiscovery() async {
    setState(() => statusText = "Searching for Lender...");
    try {
      bool a = await Nearby().startDiscovery(
        widget.rentalId,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          if (name == widget.rentalId) {
            setState(() => statusText = "Found Lender! Connecting...");
            Nearby().requestConnection(
              "Borrower",
              id,
              onConnectionInitiated: _onConnectionInit,
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  _sendHandshakeToken(id);
                }
              },
              onDisconnected: (id) {},
            );
          }
        },
        onEndpointLost: (id) {},
      );
      if (!a) setState(() => statusText = "Failed to start searching.");
    } catch (e) {
      setState(() => statusText = "Error: $e");
    }
  }

  // ----------------------------------------------------------------
  // 🤝 THE BLE HANDSHAKE (CONNECTION APPROVAL)
  // ----------------------------------------------------------------
  void _onConnectionInit(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          String receivedToken = String.fromCharCodes(payload.bytes!);
          String expectedToken = "${widget.actionType.toUpperCase()}_CONFIRMED_${widget.rentalId}";

          if (widget.isLender && receivedToken == expectedToken) {
            _executeStateChangeAndComplete();
          }
        }
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
  }

  void _sendHandshakeToken(String endpointId) {
    setState(() => statusText = "Sending verification token...");
    String token = "${widget.actionType.toUpperCase()}_CONFIRMED_${widget.rentalId}";
    Nearby().sendBytesPayload(endpointId, Uint8List.fromList(token.codeUnits));
  }

  // ----------------------------------------------------------------
  // 📷 🚀 THE QR CODE HANDSHAKE (FALLBACK)
  // ----------------------------------------------------------------
  void _onQRDetected(BarcodeCapture capture) {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    String expectedToken = "${widget.actionType.toUpperCase()}_CONFIRMED_${widget.rentalId}";

    for (final barcode in barcodes) {
      if (barcode.rawValue == expectedToken) {
        _executeStateChangeAndComplete();
        break;
      }
    }
  }

  // ----------------------------------------------------------------
  // 💎 LENDER VERIFIES TOKEN & UPDATES DB
  // ----------------------------------------------------------------
  Future<void> _executeStateChangeAndComplete() async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      statusText = widget.actionType == 'pickup'
          ? "Verifying pickup..."
          : "Securing return... pending review.";
    });

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference rentalRef = FirebaseFirestore.instance.collection('rentals').doc(widget.rentalId);

        if (widget.actionType == 'pickup') {
          transaction.update(rentalRef, {
            'status': 'Active',
            'pickedUpAt': FieldValue.serverTimestamp(),
          });
        }
        else if (widget.actionType == 'return') {
          transaction.update(rentalRef, {
            'status': 'Returned_pending_review',
            'returnedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _cleanupConnections();

      if (widget.actionType == 'pickup') {
        _finishHandshakeAndPop("Pickup Confirmed! Tool is handed over. 🛠️");
      } else {
        // 🚀 IF RETURNED: Owner is instantly hit with the compulsory review!
        _showCompulsoryReviewDialog();
      }
    } catch (e) {
      setState(() {
        isProcessing = false;
        statusText = "Database Error: $e";
      });
    }
  }

  // ============================================================================
  // ⭐ COMPULSORY REVIEW DIALOG & SECURITY DEPOSIT RELEASE
  // ============================================================================
  void _showCompulsoryReviewDialog() {
    int selectedRating = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false, // 🛡️ Trap them until they finish!
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text("Handover Complete! ⭐", textAlign: TextAlign.center),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isLender
                          ? "Inspect the tool. How was the Borrower?"
                          : "Rate the Tool & Owner:",
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 0,
                      children: List.generate(5, (index) {
                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFF8C00),
                            size: 36,
                          ),
                          onPressed: () => setState(() => selectedRating = index + 1),
                        );
                      }),
                    ),

                    // 💰 LENDER ONLY: Explain the financial action
                    if (widget.isLender) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          "Does the tool look good? Approving this will initiate the security deposit refund to the borrower.",
                          style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      )
                    ]
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ THE HAPPY PATH BUTTON
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          _processSubmission(context, selectedRating, isDamaged: false);
                        },
                        child: Text(
                            widget.isLender ? "Tool is Fine - Refund Deposit" : "Submit Review",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                      ),

                      // 🚨 THE DISPUTE BUTTON (Only for Lenders)
                      if (widget.isLender) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            _processSubmission(context, selectedRating, isDamaged: true);
                          },
                          child: const Text("Tool is Damaged - Hold Deposit",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ]
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _processSubmission(BuildContext context, int rating, {required bool isDamaged}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await _submitReviewAndProcessDeposit(rating, isDamaged: isDamaged);

    if (context.mounted) {
      Navigator.pop(context); // 1. Close Loading Circle
      Navigator.pop(context); // 2. Close Review Dialog
      Navigator.pop(context); // 3. Close Handshake Screen (Back to History)

      String msg = "Review saved! 🌟";
      if (widget.isLender) {
        msg = isDamaged ? "Dispute opened. Deposit withheld. 🚨" : "Refund initiated! 💰";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isDamaged ? Colors.red : Colors.green),
      );
    }
  }

  // 🧮 TRUST SCORE MATH & 💰 SECURITY DEPOSIT TRIGGER
  Future<void> _submitReviewAndProcessDeposit(int rating, {required bool isDamaged}) async {
    final db = FirebaseFirestore.instance;
    String targetUserId = widget.isLender ? widget.rentalData['borrowerId'] : widget.rentalData['lenderId'];
    String toolId = widget.rentalData['toolId'];

    try {
      await db.runTransaction((transaction) async {
        DocumentReference rentalRef = db.collection('rentals').doc(widget.rentalId);

        // 1. Update Rental Document & Trigger the Backend Refund
        Map<String, dynamic> rentalUpdates = {};

        if (widget.isLender) {
          rentalUpdates['lenderReviewed'] = true;

          if (isDamaged) {
            rentalUpdates['status'] = 'Disputed';
            rentalUpdates['securityDepositStatus'] = 'Withheld'; // Keeps the money safe
          } else {
            rentalUpdates['status'] = 'Completed';
            // 🚀 THIS IS WHAT YOUR CLOUD FUNCTION WILL LISTEN FOR TO DO THE ACTUAL REFUND:
            rentalUpdates['securityDepositStatus'] = 'Refund_Requested';
          }
        } else {
          rentalUpdates['borrowerReviewed'] = true;
        }
        transaction.update(rentalRef, rentalUpdates);

        // 2. Update Target User's Trust Score
        DocumentReference userRef = db.collection('users').doc(targetUserId);
        DocumentSnapshot userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          double currentScore = (userData != null && userData.containsKey('trustScore'))
              ? (userData['trustScore'] as num).toDouble() : 5.0;
          int reviewCount = (userData != null && userData.containsKey('reviewCount'))
              ? (userData['reviewCount'] as num).toInt() : 0;

          double newScore = ((currentScore * reviewCount) + rating) / (reviewCount + 1);

          transaction.update(userRef, {
            'trustScore': double.parse(newScore.toStringAsFixed(1)),
            'reviewCount': reviewCount + 1,
          });
        }

        // 3. If Borrower is reviewing, update Tool's rating
        if (!widget.isLender) {
          DocumentReference toolRef = db.collection('tools').doc(toolId);
          DocumentSnapshot toolDoc = await transaction.get(toolRef);

          if (toolDoc.exists) {
            final toolData = toolDoc.data() as Map<String, dynamic>?;
            double currentToolScore = (toolData != null && toolData.containsKey('rating'))
                ? (toolData['rating'] as num).toDouble() : 5.0;
            int toolReviewCount = (toolData != null && toolData.containsKey('reviewCount'))
                ? (toolData['reviewCount'] as num).toInt() : 0;

            double newToolScore = ((currentToolScore * toolReviewCount) + rating) / (toolReviewCount + 1);

            transaction.update(toolRef, {
              'rating': double.parse(newToolScore.toStringAsFixed(1)),
              'reviewCount': toolReviewCount + 1,
            });
          }
        }

        // 4. Mark Tool as available ONLY if the lender says it isn't damaged
        if (widget.isLender && !isDamaged) {
          transaction.update(db.collection('tools').doc(toolId), {'isAvailable': true});
        } else if (widget.isLender && isDamaged) {
          transaction.update(db.collection('tools').doc(toolId), {'isAvailable': false});
        }
      });
    } catch (e) {
      debugPrint("Failed to submit review: $e");
    }
  }

  // ============================================================================
  // 🎨 THE UI BUILD METHOD (This was missing!)
  // ============================================================================
  String _getScreenTitle() {
    if (widget.actionType == 'pickup') {
      return widget.isLender ? "You are handing over the tool." : "You are picking up the tool.";
    } else {
      return widget.isLender ? "You are receiving the tool back." : "You are returning the tool.";
    }
  }

  @override
  Widget build(BuildContext context) {
    String secureToken = "${widget.actionType.toUpperCase()}_CONFIRMED_${widget.rentalId}";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.actionType == 'pickup' ? "Pickup Verification" : "Return Verification"),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isUsingQR = !_isUsingQR;
                if (_isUsingQR) _cleanupConnections();
              });
            },
            icon: Icon(_isUsingQR ? Icons.bluetooth : Icons.qr_code, color: Colors.white),
            label: Text(_isUsingQR ? "Use Bluetooth" : "Use QR Code", style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getScreenTitle(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              if (!_isUsingQR) ...[
                Icon(widget.isLender ? Icons.wifi_tethering : Icons.radar, size: 100, color: const Color(0xFFFF8C00)),
                const SizedBox(height: 20),
                const Text("Keep both phones close to each other. Bluetooth must be ON.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),

                if (!isProcessing)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00), minimumSize: const Size(double.infinity, 55)),
                    onPressed: widget.isLender ? _startAdvertising : _startDiscovery,
                    child: Text(widget.isLender ? "START BROADCASTING" : "SCAN FOR OWNER", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ] else ...[
                if (!widget.isLender) ...[
                  const Text("Show this QR Code to the Owner", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: QrImageView(data: secureToken, version: QrVersions.auto, size: 250.0),
                  ),
                ] else ...[
                  const Text("Scan the Borrower's QR Code", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: MobileScanner(onDetect: _onQRDetected),
                    ),
                  ),
                ]
              ],

              const SizedBox(height: 40),
              Text(
                statusText,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusText.contains("Confirmed") || statusText.contains("Verified") ? Colors.green : Colors.black87
                ),
                textAlign: TextAlign.center,
              ),
              if (isProcessing && !statusText.contains("Verified"))
                const Padding(
                  padding: EdgeInsets.only(top: 20.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}