Widget _buildCustomerCard(Customer customer) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent,
              image: customer.logoPath != null && File(customer.logoPath!).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(customer.logoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: customer.logoPath == null || !File(customer.logoPath!).existsSync()
                ? Icon(Icons.person, color: Colors.white, size: 28)
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                // Dati Principali
                if (customer.vatNumber?.isNotEmpty == true || customer.taxCode?.isNotEmpty == true || customer.sdiCode?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.vatNumber?.isNotEmpty == true)
                          Text('P.IVA: ${customer.vatNumber}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.taxCode?.isNotEmpty == true)
                          Text('C.F.: ${customer.taxCode}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.sdiCode?.isNotEmpty == true)
                          Text('SDI: ${customer.sdiCode}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                      ],
                    ),
                  ),

                // Sede
                if (customer.addressStreet?.isNotEmpty == true || customer.addressCity?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.white.withOpacity(0.54), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              customer.addressStreet,
                              if (customer.addressZip?.isNotEmpty == true) customer.addressZip,
                              customer.addressCity,
                              if (customer.addressProvince?.isNotEmpty == true) '(${customer.addressProvince})'
                            ].where((e) => e != null && e.toString().isNotEmpty).join(' '),
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contatti
                if (customer.email?.isNotEmpty == true || customer.pec?.isNotEmpty == true || customer.phone?.isNotEmpty == true || customer.contacts?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.email?.isNotEmpty == true)
                          Row(children: [Icon(Icons.email, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.email!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.pec?.isNotEmpty == true)
                          Row(children: [Icon(Icons.mark_email_read, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text('PEC: ${customer.pec}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.phone?.isNotEmpty == true)
                          Row(children: [Icon(Icons.phone, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.phone!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.contacts?.isNotEmpty == true && customer.email?.isEmpty == true && customer.phone?.isEmpty == true)
                          Row(children: [Icon(Icons.contact_mail, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.contacts!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                      ],
                    ),
                  ),

                // Codici PA
                if (customer.cig?.isNotEmpty == true || customer.cup?.isNotEmpty == true || customer.paReference?.isNotEmpty == true || customer.paContract?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.cig?.isNotEmpty == true || customer.cup?.isNotEmpty == true)
                          Text(
                            'CIG: ${customer.cig ?? "-"} | CUP: ${customer.cup ?? "-"}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                          ),
                        if (customer.paReference?.isNotEmpty == true)
                          Text('Rif. Ammin.: ${customer.paReference}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.paContract?.isNotEmpty == true)
                          Text('Commessa/Conv.: ${customer.paContract}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _showCustomerDialog(customer),
                tooltip: 'Modifica',
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _deleteCustomer(customer.id!),
                tooltip: 'Elimina',
              ),
            ],
          ),
        ],
      ),
    );
  }

  