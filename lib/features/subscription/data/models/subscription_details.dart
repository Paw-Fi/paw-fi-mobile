class SubscriptionDetails {
  final Subscription? subscription;
  final List<SubscriptionFeature>? features;
  final PaymentMethod? paymentMethod;
  final List<Invoice> invoices;
  final int? daysUntilNextPayment;

  SubscriptionDetails({
    this.subscription,
    this.features,
    this.paymentMethod,
    required this.invoices,
    this.daysUntilNextPayment,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetails(
      subscription: json['subscription'] != null
          ? Subscription.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
      features: json['features'] != null
          ? (json['features'] as List)
              .map((f) => SubscriptionFeature.fromJson(f as Map<String, dynamic>))
              .toList()
          : null,
      paymentMethod: json['payment_method'] != null
          ? PaymentMethod.fromJson(json['payment_method'] as Map<String, dynamic>)
          : null,
      invoices: json['invoices'] != null
          ? (json['invoices'] as List)
              .map((i) => Invoice.fromJson(i as Map<String, dynamic>))
              .toList()
          : [],
      daysUntilNextPayment: json['days_until_next_payment'] as int?,
    );
  }

  String get planDisplayName {
    if (subscription?.plan == null || subscription?.plan?.toLowerCase() == 'free') {
      return 'Free';
    }
    
    switch (subscription!.plan!.toLowerCase()) {
      case 'lifetime':
        return 'Lifetime';
      case 'plus':
        return 'Plus';
      case 'monthly':
        return 'Plus Monthly';
      case 'yearly':
        return 'Plus Yearly';
      default:
        return subscription!.plan!.toUpperCase();
    }
  }

  String get statusDisplayName {
    if (subscription?.plan == null || subscription?.plan?.toLowerCase() == 'free') {
      return 'Free plan';
    }
    
    switch (subscription!.status?.toLowerCase()) {
      case 'active':
        return isLifetime ? 'Active • Lifetime' : 'Active';
      case 'canceled':
        return 'Canceled';
      case 'past_due':
        return 'Past due';
      case 'trialing':
        return 'Trial';
      default:
        return subscription!.status ?? 'Unknown';
    }
  }

  String? get renewalInfo {
    if (subscription == null || isLifetime) {
      return null;
    }

    if (subscription!.status?.toLowerCase() == 'trialing' && subscription!.currentPeriodEnd != null) {
      final trialEnd = subscription!.currentPeriodEnd!;
      final now = DateTime.now();
      final daysLeft = trialEnd.difference(now).inDays;
      
      if (daysLeft > 0) {
        return 'Trial ends in $daysLeft days';
      } else {
        return 'Trial ended';
      }
    }

    if (subscription!.status?.toLowerCase() == 'active' && daysUntilNextPayment != null && daysUntilNextPayment! > 0) {
      return 'Renews in $daysUntilNextPayment days';
    }

    if (subscription!.status?.toLowerCase() == 'canceled' && subscription!.currentPeriodEnd != null) {
      final endDate = subscription!.currentPeriodEnd!;
      final now = DateTime.now();
      final daysLeft = endDate.difference(now).inDays;
      
      if (daysLeft > 0) {
        return 'Access ends in $daysLeft days';
      } else {
        return 'Subscription ended';
      }
    }

    return null;
  }

  bool get hasActiveSubscription {
    if (subscription?.plan == null || subscription?.plan?.toLowerCase() == 'free') {
      return false;
    }
    
    final status = subscription!.status?.toLowerCase();
    return status == 'active' || status == 'trialing';
  }

  bool get isLifetime {
    return subscription?.plan?.toLowerCase() == 'lifetime';
  }

  bool get isTrialing {
    return subscription?.status?.toLowerCase() == 'trialing';
  }

  bool get isActive {
    return subscription?.status?.toLowerCase() == 'active';
  }

  bool get isCanceled {
    return subscription?.status?.toLowerCase() == 'canceled';
  }

  bool get isPastDue {
    return subscription?.status?.toLowerCase() == 'past_due';
  }

  bool get isFree {
    return subscription?.plan == null || subscription?.plan?.toLowerCase() == 'free';
  }
}

class Subscription {
  final String id;
  final String? plan;
  final String? status;
  final DateTime? currentPeriodEnd;
  final DateTime? nextPaymentDate;
  final bool? cancelAtPeriodEnd;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    this.plan,
    this.status,
    this.currentPeriodEnd,
    this.nextPaymentDate,
    this.cancelAtPeriodEnd,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      plan: json['plan'] as String?,
      status: json['status'] as String?,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      nextPaymentDate: json['next_payment_date'] != null
          ? DateTime.parse(json['next_payment_date'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class SubscriptionFeature {
  final String name;
  final String? description;
  final bool enabled;

  SubscriptionFeature({
    required this.name,
    this.description,
    required this.enabled,
  });

  factory SubscriptionFeature.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeature(
      name: json['name'] as String,
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

class PaymentMethod {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      brand: json['brand'] as String,
      last4: json['last4'] as String,
      expMonth: json['exp_month'] as int,
      expYear: json['exp_year'] as int,
    );
  }

  String get displayName {
    return '${brand.toUpperCase()} •••• $last4';
  }
}

class Invoice {
  final String id;
  final double amountPaid;
  final String currency;
  final String status;
  final DateTime created;
  final String? hostedInvoiceUrl;
  final String? pdf;

  Invoice({
    required this.id,
    required this.amountPaid,
    required this.currency,
    required this.status,
    required this.created,
    this.hostedInvoiceUrl,
    this.pdf,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      created: DateTime.parse(json['created'] as String),
      hostedInvoiceUrl: json['hosted_invoice_url'] as String?,
      pdf: json['pdf'] as String?,
    );
  }

  String get formattedAmount {
    return '${currency.toUpperCase()} ${amountPaid.toStringAsFixed(2)}';
  }
}
