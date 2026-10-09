# -*- coding: utf-8 -*-
import sys

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                                                        InkWell(
                                                          onTap: () => _downloadSinglePayment(p),
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: const [
                                                                Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 18),
                                                                SizedBox(height: 2),
                                                                Text(
                                                                  'PDF',
                                                                  style: TextStyle(
                                                                    color: Color(0xFF22D3EE),
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),'''

target_alt = '''                                                        InkWell(
                                                          onTap: () => _openAttachment(payment),
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.2)),
                                                            ),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: const [
                                                                Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 18),
                                                                SizedBox(height: 2),
                                                                Text(
                                                                  'PDF',
                                                                  style: TextStyle(
                                                                    color: Color(0xFF22D3EE),
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),'''

new_btn = '''                                                        IconButton(
                                                          onPressed: () => _openAttachment(payment),
                                                          icon: const Icon(Icons.download_rounded, color: Color(0xFF22D3EE), size: 22),
                                                          tooltip: 'Scarica',
                                                        ),'''

# Wait! The one with _downloadSinglePayment(p) was in dashboard or scheduled? Let me check!
