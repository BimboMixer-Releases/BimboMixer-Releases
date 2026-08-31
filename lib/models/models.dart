class Customer {
  final String? id;
  final String name;
  final String? vatNumber;
  final String? sdiCode;
  final String? taxCode;
  final String? addressStreet;
  final String? addressZip;
  final String? addressCity;
  final String? addressProvince;
  final String? email;
  final String? pec;
  final String? phone;
  final String? contacts; // legacy
  final String? cig;
  final String? cup;
  final String? paReference; // Riferimento Amministrazione / Numero Ordine
  final String? paContract; // Codice Commessa / Convenzione
  final String? logoPath;

  Customer({
    this.id,
    required this.name,
    this.vatNumber,
    this.sdiCode,
    this.taxCode,
    this.addressStreet,
    this.addressZip,
    this.addressCity,
    this.addressProvince,
    this.email,
    this.pec,
    this.phone,
    this.contacts,
    this.cig,
    this.cup,
    this.paReference,
    this.paContract,
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'vat_number': vatNumber,
      'sdi_code': sdiCode,
      'tax_code': taxCode,
      'address_street': addressStreet,
      'address_zip': addressZip,
      'address_city': addressCity,
      'address_province': addressProvince,
      'email': email,
      'pec': pec,
      'phone': phone,
      'contacts': contacts,
      'cig': cig,
      'cup': cup,
      'pa_reference': paReference,
      'pa_contract': paContract,
      'logo_path': logoPath,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, [String? id]) {
    return Customer(
      id: id ?? map['id']?.toString(),
      name: map['name']?.toString() ?? 'Sconosciuto',
      vatNumber: map['vat_number']?.toString(),
      sdiCode: map['sdi_code']?.toString(),
      taxCode: map['tax_code']?.toString(),
      addressStreet: map['address_street']?.toString(),
      addressZip: map['address_zip']?.toString(),
      addressCity: map['address_city']?.toString(),
      addressProvince: map['address_province']?.toString(),
      email: map['email']?.toString(),
      pec: map['pec']?.toString(),
      phone: map['phone']?.toString(),
      contacts: map['contacts']?.toString(),
      cig: map['cig']?.toString(),
      cup: map['cup']?.toString(),
      paReference: map['pa_reference']?.toString(),
      paContract: map['pa_contract']?.toString(),
      logoPath: map['logo_path']?.toString(),
    );
  }
}

class Category {
  final String? id;
  final String name;
  final String type; // 'IN' (Entrata) or 'OUT' (Uscita)
  final String? colorHex;

  Category({this.id, required this.name, required this.type, this.colorHex});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color_hex': colorHex,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, [String? id]) {
    return Category(
      id: id ?? map['id']?.toString(),
      name: map['name']?.toString() ?? 'Sconosciuta',
      type: map['type']?.toString() ?? 'OUT',
      colorHex: map['color_hex']?.toString(),
    );
  }
}

class ServiceType {
  final String? id;
  final String name;
  final String? colorHex;

  ServiceType({this.id, required this.name, this.colorHex});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_hex': colorHex,
    };
  }

  factory ServiceType.fromMap(Map<String, dynamic> map, [String? id]) {
    return ServiceType(
      id: id ?? map['id']?.toString(),
      name: map['name']?.toString() ?? 'Sconosciuto',
      colorHex: map['color_hex']?.toString(),
    );
  }
}

class Payment {
  final String? id;
  final String type; // 'IN' or 'OUT'
  final double amount;
  final String date;
  final String? customerId;
  final String? categoryId;
  final String? serviceId;
  final String? paymentMethod; // 'Fattura' or 'Contante'
  final String? attachments; // JSON string of file paths
  final String status; // 'PAID' or 'PENDING'
  final String? notes; // Additional notes e.g. for split logic
  final String? eventDates; // Storing intervals as text or JSON
  final String? dateTo; // Optional end date for scheduled payments
  final String? title;
  final String? clientPhone;
  final String? clientEmail;

  Payment({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.customerId,
    this.categoryId,
    this.serviceId,
    this.paymentMethod,
    this.attachments,
    this.status = 'PAID',
    this.notes,
    this.eventDates,
    this.dateTo,
    this.title,
    this.clientPhone,
    this.clientEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'date': date,
      'customer_id': customerId,
      'category_id': categoryId,
      'service_id': serviceId,
      'payment_method': paymentMethod,
      'attachments': attachments,
      'status': status,
      'notes': notes,
      'event_dates': eventDates,
      'date_to': dateTo,
      'title': title,
      'client_phone': clientPhone,
      'client_email': clientEmail,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map, [String? id]) {
    return Payment(
      id: id ?? map['id']?.toString(),
      type: map['type']?.toString() ?? 'OUT',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      date: map['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
      customerId: map['customer_id']?.toString(),
      categoryId: map['category_id']?.toString(),
      serviceId: map['service_id']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      attachments: map['attachments']?.toString(),
      status: map['status']?.toString() ?? 'PAID',
      notes: map['notes']?.toString(),
      eventDates: map['event_dates']?.toString(),
      dateTo: map['date_to']?.toString(),
      title: map['title']?.toString(),
      clientPhone: map['client_phone']?.toString(),
      clientEmail: map['client_email']?.toString(),
    );
  }
}

class User {
  final String? id;
  final String username;
  final String passwordHash;
  final String role;
  final String? email;
  final String? phone;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'email': email,
      'phone': phone,
    };
  }

  factory User.fromMap(Map<String, dynamic> map, [String? id]) {
    return User(
      id: id ?? map['id']?.toString(),
      username: map['username']?.toString() ?? 'Utente',
      passwordHash: map['password_hash']?.toString() ?? '',
      role: map['role']?.toString() ?? 'User',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
    );
  }
}

class Invoice {
  final String? id;
  final String date;
  final double amount;
  final String? customerId;
  final String? number;
  final String status;
  final String? notes;
  final String? eventDate;
  final String? vatCode;

  Invoice({
    this.id,
    required this.date,
    required this.amount,
    this.customerId,
    this.number,
    this.status = 'PENDING',
    this.notes,
    this.eventDate,
    this.vatCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'customer_id': customerId,
      'number': number,
      'status': status,
      'notes': notes,
      'event_date': eventDate,
      'vat_code': vatCode,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, [String? id]) {
    return Invoice(
      id: id ?? map['id']?.toString(),
      date: map['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      customerId: map['customer_id']?.toString(),
      number: map['number']?.toString(),
      status: map['status']?.toString() ?? 'PENDING',
      notes: map['notes']?.toString(),
      eventDate: map['event_date']?.toString(),
      vatCode: map['vat_code']?.toString(),
    );
  }
}

class Deadline {
  final String? id;
  final String date;
  final double amount;
  final String title;
  final String? categoryId;
  final String status;

  Deadline({
    this.id,
    required this.date,
    required this.amount,
    required this.title,
    this.categoryId,
    this.status = 'PENDING',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'title': title,
      'category_id': categoryId,
      'status': status,
    };
  }

  factory Deadline.fromMap(Map<String, dynamic> map, [String? id]) {
    return Deadline(
      id: id ?? map['id']?.toString(),
      date: map['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      title: map['title']?.toString() ?? 'Scadenza',
      categoryId: map['category_id']?.toString(),
      status: map['status']?.toString() ?? 'PENDING',
    );
  }
}