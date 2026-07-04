import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class FarmMapView extends StatelessWidget {
  final List<SensorNode> sensors;

  const FarmMapView({Key? key, required this.sensors}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false, // Allows panning over the large map
      minScale: 0.5,
      maxScale: 3.0,
      boundaryMargin: const EdgeInsets.all(50),
      child: Center(
        child: Container(
          width: 400,
          height: sensors.length >= 200 ? 1400 : 900,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                    ),
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
              // Farm Labels
              const Positioned(
                top: 16,
                left: 16,
                child: Text(
                  'Greenhouse A1',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              // Render dots based on count
              Positioned.fill(
                child: _buildSensorDots(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorDots() {
    int total = sensors.length;

    if (total >= 200) {
      // 250 nodes - nice dense grid
      return Padding(
        padding: const EdgeInsets.only(top: 60, bottom: 20, left: 10, right: 10),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            final node = sensors[index];
            return Tooltip(
              message: '${node.name}\n${node.valueDisplay} ${node.unit}',
              child: Container(
                decoration: BoxDecoration(
                  color: node.isWarning ? Colors.red : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      );
    } else if (total > 1) {
      // 6 nodes - spaced out
      return Padding(
        padding: const EdgeInsets.only(top: 100, bottom: 100, left: 40, right: 40),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 50,
            mainAxisSpacing: 100,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            final node = sensors[index];
            return Center(
              child: Tooltip(
                message: '${node.name}\n${node.valueDisplay} ${node.unit}',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: node.isWarning ? Colors.red : Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${index+1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      // 1 water pump
      final node = sensors.first;
      return Center(
        child: Tooltip(
          message: '${node.name}\n${node.valueDisplay} ${node.unit}',
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: node.isWarning ? Colors.red : Colors.purple,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
              ]
            ),
            child: const Center(
              child: Icon(Icons.water_drop, color: Colors.white, size: 40),
            ),
          ),
        ),
      );
    }
  }
}
