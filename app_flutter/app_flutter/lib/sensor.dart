import 'package:json_annotation/json_annotation.dart';
import './data.dart';
part 'sensor.g.dart';

@JsonSerializable()
class Sensor {
  Data data;

  Sensor(this.data);

  factory Sensor.fromJson(Map<String, dynamic> json) => _$SensorFromJson(json);
  Map<String, dynamic> toJson() => _$SensorToJson(this);
}
