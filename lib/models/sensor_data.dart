class SensorNode {
  final int id;
  final String name;
  final String valueDisplay;
  final double numericValue;
  final String unit;
  final bool isWarning;

  SensorNode({
    required this.id,
    required this.name,
    required this.valueDisplay,
    required this.numericValue,
    required this.unit,
    this.isWarning = false,
  });
}
