  Widget build(BuildContext context) {
    final filtered = _filteredPayments;

    return GradientScaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 24.0,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // 1. TOP HEADER BAR: Welcome, User | Search | Notifications | AXION Logo
                    _buildTopHeaderBar(),

                    const SizedBox(height: 28),

                    // 2. PAGE TITLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Invoices & Transactions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Quick Action Buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.print_outlined,
                                color: Color(0xFF38BDF8),
                                size: 22,
                              ),
                              tooltip: 'Esporta Report PDF',
                              onPressed: _exportPdfReport,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PaymentFormScreen(),
                                  ),
                                );
                                _loadPayments();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEC4899),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(
                                  0xFFEC4899,
                                ).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Nuova Fattura',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                    Container(
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF131728,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFEC4899,
                              ).withValues(alpha: 0.05),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Card Header: Title + Filter Chips + Options
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        const Text(
                                          'Transactions Overview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatusFilterChip('Tutti'),
                                        _buildStatusFilterChip('Saldato'),
                                        _buildStatusFilterChip('In Attesa'),
                                      ],
                                    ),
                                  ),

                                  // Three Dots Menu
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      color: Colors.white54,
                                      size: 22,
                                    ),
                                    color: const Color(0xFF16192B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    onSelected: (action) {
                                      if (action == 'export_pdf') {
                                        _exportPdfReport();
                                      } else if (action == 'new') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PaymentFormScreen(),
                                          ),
                                        ).then((_) => _loadPayments());
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'export_pdf',
                                        child: Text(
                                          'Esporta Report PDF',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'new',
                                        child: Text(
                                          'Nuovo Movimento',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Table Area with Horizontal Scroll for Mobile
                            LayoutBuilder(
                                builder: (context, constraints) {
                                  final double minTableWidth = 900.0;
                                  final double actualWidth =
                                      constraints.maxWidth > minTableWidth
                                      ? constraints.maxWidth
                                      : minTableWidth;

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: actualWidth,
                                      child: Column(
                                        children: [
                                          // Table Header Capsule Strip
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Invoice ID',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    'Client Name',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Date',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    'Description',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'Amount',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Expanded(
                                                  flex: 3,
                                                  child: Center(
                                                    child: Text(
                                                      'Status',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 100,
                                                  child: Center(
                                                    child: Text(
                                                      'Action',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          // Table Rows List
                                          filtered.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      'Nessun movimento trovato.',
                                                      style: TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  )
                                                : ListView.separated(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 8,
                                                        ),
                                                    itemCount: filtered.length,
                                                    separatorBuilder:
                                                        (ctx, i) => Divider(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                          height: 1,
                                                        ),
                                                    itemBuilder: (context, index) {
                                                      final p = filtered[index];
                                                      final id =
                                                          p['id']?.toString() ??
                                                          '';

                                                      final invoiceId =
                                                          _formatInvoiceId(
                                                            index,
                                                          );
                                                      final clientName =
                                                          p['customer_name']
                                                                  ?.toString()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? p['customer_name']
                                                                .toString()
                                                          : 'Cliente Generico';
                                                      final dateStr =
                                                          _formatDate(
                                                            p['date'],
                                                          );
                                                      final desc =
                                                          p['service_name']
                                                                  ?.toString()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? p['service_name']
                                                                .toString()
                                                          : (p['notes']
                                                                        ?.toString()
                                                                        .isNotEmpty ==
                                                                    true
                                                                ? p['notes']
                                                                      .toString()
                                                                : (p['payment_method'] ??
                                                                      'Prestazione'));
                                                      final amountVal =
                                                          double.tryParse(
                                                            p['amount']
                                                                    ?.toString() ??
                                                                '0',
                                                          ) ??
                                                          0.0;
                                                      final isIN =
                                                          p['type'] == 'IN';
                                                      final isPaid =
                                                          p['status'] ==
                                                              'PAID' ||
                                                          p['status'] ==
                                                              'Saldato' ||
                                                          p['status'] ==
                                                              'Pagato' ||
                                                          (p['status'] ==
                                                                  null &&
                                                              isIN);

                                                      return InkWell(
                                                        onTap: () async {
                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  PaymentSummaryScreen(
                                                                    paymentId:
                                                                        p['id'],
                                                                  ),
                                                            ),
                                                          );
                                                          _loadPayments();
                                                        },
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .transparent,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 16,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              // Invoice ID
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  invoiceId,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    letterSpacing:
                                                                        0.2,
                                                                  ),
                                                                ),
                                                              ),

                                                              // Client Name
                                                              Expanded(
                                                                flex: 4,
                                                                child: Text(
                                                                  clientName,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),

                                                              // Date
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  dateStr,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),

                                                              // Description
                                                              Expanded(
                                                                flex: 4,
                                                                child: Text(
                                                                  desc,
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),

                                                              // Amount
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  'â‚¬ ${amountVal.toStringAsFixed(2)}',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    letterSpacing:
                                                                        0.2,
                                                                  ),
                                                                ),
                                                              ),

                                                              // Status Neon Badge: Cyan PAID / Magenta PENDING
                                                              Expanded(
                                                                flex: 3,
                                                                child: Center(
                                                                  child: InkWell(
                                                                    onTap: () =>
                                                                        _toggleStatus(
                                                                          p,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            18,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            isPaid
                                                                            ? const Color(
                                                                                0xFF22D3EE,
                                                                              ).withValues(
                                                                                alpha: 0.12,
                                                                              )
                                                                            : const Color(
                                                                                0xFFEC4899,
                                                                              ).withValues(
                                                                                alpha: 0.12,
                                                                              ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              20,
                                                                            ),
                                                                        border: Border.all(
                                                                          color:
                                                                              isPaid
                                                                              ? const Color(
                                                                                  0xFF22D3EE,
                                                                                )
                                                                              : const Color(
                                                                                  0xFFEC4899,
                                                                                ),
                                                                          width:
                                                                              1.4,
                                                                        ),
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                            color:
                                                                                (isPaid
                                                                                        ? const Color(
                                                                                            0xFF22D3EE,
                                                                                          )
                                                                                        : const Color(
                                                                                            0xFFEC4899,
                                                                                          ))
                                                                                    .withValues(
                                                                                      alpha: 0.45,
                                                                                    ),
                                                                            blurRadius:
                                                                                10,
                                                                            spreadRadius:
                                                                                0.5,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      child: Text(
                                                                        isPaid
                                                                            ? 'Saldato'
                                                                            : 'In Attesa',
                                                                        style: TextStyle(
                                                                          color:
                                                                              isPaid
                                                                              ? const Color(
                                                                                  0xFF22D3EE,
                                                                                )
                                                                              : const Color(
                                                                                  0xFFEC4899,
                                                                                ),
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          letterSpacing:
                                                                              1.0,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),

                                                              // Action Column: Download Icon & Button
                                                              SizedBox(
                                                                width: 100,
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    InkWell(
                                                                      onTap: () =>
                                                                          _downloadSinglePayment(
                                                                            p,
                                                                          ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                      child: Padding(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              4,
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                        child: Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: const [
                                                                            Icon(
                                                                              Icons.download_rounded,
                                                                              color: Color(
                                                                                0xFF22D3EE,
                                                                              ),
                                                                              size: 18,
                                                                            ),
                                                                            SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                            Text(
                                                                              'PDF',
                                                                              style: TextStyle(
                                                                                color: Color(
                                                                                  0xFF22D3EE,
                                                                                ),
                                                                                fontSize: 9,
                                                                                fontWeight: FontWeight.w500,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    IconButton(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .edit_outlined,
                                                                        color: Colors
                                                                            .white70,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      tooltip:
                                                                          'Modifica',
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      constraints:
                                                                          const BoxConstraints(),
                                                                      onPressed: () =>
                                                                          _editPayment(
                                                                            p,
                                                                          ),
                                                                    ),
                                                                    IconButton(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .delete_outline,
                                                                        color: Colors
                                                                            .white38,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      hoverColor: Colors
                                                                          .red
                                                                          .withValues(
                                                                            alpha:
                                                                                0.2,
                                                                          ),
                                                                      tooltip:
                                                                          'Elimina',
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      constraints:
                                                                          const BoxConstraints(),
                                                                      onPressed: () =>
                                                                          _deletePayment(
                                                                            id,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Top Header Bar: Welcome text, Search input, notification bell, AXION logo
  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Welcome Text removed
        const SizedBox(),

        // Right side: Search Box + Bell + AXION Brand
        Row(
          children: [
            // Search Box Capsule
            Container(
              width: 240,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF16192B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white38,
                        size: 14,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String label) {
    final isSelected = _statusFilter == label;
    Color color = const Color(0xFF38BDF8);
    if (label == 'Saldato') color = const Color(0xFF22D3EE);
    if (label == 'In Attesa') color = const Color(0xFFEC4899);

    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
