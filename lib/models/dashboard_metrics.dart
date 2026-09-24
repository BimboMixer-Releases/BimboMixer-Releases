class DashboardMetrics {
  final double totalIn;
  final double totalOut;
  final double patrimonio;
  final double margine;
  final Map<int, double> monthlyNet;
  final Map<int, double> monthlyIn;
  final Map<int, double> monthlyOut;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> serviceBreakdown;
  final Map<String, double> paymentMethodBreakdown;
  final double totalDeadlinesPaid;

  DashboardMetrics({
    required this.totalIn,
    required this.totalOut,
    required this.patrimonio,
    required this.margine,
    required this.monthlyNet,
    required this.monthlyIn,
    required this.monthlyOut,
    required this.categoryBreakdown,
    required this.serviceBreakdown,
    required this.paymentMethodBreakdown,
    required this.totalDeadlinesPaid,
  });

  factory DashboardMetrics.empty() {
    return DashboardMetrics(
      totalIn: 0.0,
      totalOut: 0.0,
      patrimonio: 0.0,
      margine: 0.0,
      monthlyNet: {for (var i = 1; i <= 12; i++) i: 0.0},
      monthlyIn: {for (var i = 1; i <= 12; i++) i: 0.0},
      monthlyOut: {for (var i = 1; i <= 12; i++) i: 0.0},
      categoryBreakdown: {},
      serviceBreakdown: {},
      paymentMethodBreakdown: {},
      totalDeadlinesPaid: 0.0,
    );
  }
}
