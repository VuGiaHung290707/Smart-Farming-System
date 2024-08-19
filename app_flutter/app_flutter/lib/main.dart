import 'package:esp_app/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import './sensor.dart';
import 'data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

bool on_off = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotifications.init();
  await initializeDateFormatting();
  runApp(const MyApp());
}

IO.Socket socket = IO.io(
    'https://smart-farming-system.glitch.me',

    ///'http://192.168.1.7:3484', //'https://data-led.glitch.me',
    IO.OptionBuilder().setTransports(['websocket']).build());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farming System',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Sensor _sensorData = Sensor(Data(null));
  DateTime? _savedDateTime;
  List<DateTime> wateringTimes = []; // Example list variable name
  TextEditingController _timeController = TextEditingController();
  TextEditingController _timeController1 = TextEditingController();
  TimeOfDay? _selectedTime;
  Timer? _timer;
  DateTime? _targetDateTime;
  bool isCheckingTime = false;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text =
            picked.format(context); // Use TimeOfDay.format for time
        _saveWateringTime(
            _timeController.text); // Lưu giờ đã chọn vào Shared Preferences

        // Tính toán thời điểm mục tiêu
        final now = DateTime.now();
        _targetDateTime =
            DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        _startTimer(); // Bắt đầu hoặc khởi động lại timer
        isCheckingTime = true; // Bật cờ kiểm tra thời gian
      });
    }
  }

  Future<void> _selectTime1(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController1.text =
            picked.format(context); // Use TimeOfDay.format for time
        _saveWateringTime(
            _timeController1.text); // Lưu giờ đã chọn vào Shared Preferences

        // Tính toán thời điểm mục tiêu
        final now = DateTime.now();
        _targetDateTime =
            DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        _startTimer(); // Bắt đầu hoặc khởi động lại timer
        isCheckingTime = true; // Bật cờ kiểm tra thời gian
      });
    }
  }

  void _checkTime() async {
    if (_targetDateTime != null &&
        DateTime.now().isAfter(_targetDateTime ?? DateTime.now())) {
      LocalNotifications.showSimpleNotification(
          title: "Đã đến giờ tưới!",
          body: "Hệ thống đang tưới cây",
          payload: "Hệ thống đang tưới");
      Fluttertoast.showToast(
        msg: "Đã đến giờ tưới!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 2,
        textColor: Colors.white,
        fontSize: 16.0,
// ... các tùy chỉnh khác cho toast
      );
      WaterByHand();
      // Reset timer hoặc thực hiện các hành động khác khi đến giờ
      _targetDateTime = null;
      _timer?.cancel(); // Ngừng timer nếu cần
      isCheckingTime = false; // Tắt cờ kiểm tra
    }
  }

  @override
  void initState() {
    super.initState();
    connectAndListen();
    loadDateTime();
    loadWateringTimes();
    _on_off();
    _startTimer();
    _loadWateringTime();
    _loadWateringTime1();
  }

  _on_off() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      on_off = prefs.getBool('on_off') ?? false;
    });
  }

  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      setState(() {
        _savedDateTime = DateTime.now();
        if (isCheckingTime) {
          _checkTime();
        }
      });
    });
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;

    final parts = timeString.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadWateringTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTime = prefs.getString('wateringTime');
    if (savedTime != null) {
      setState(() {
        _timeController.text = savedTime;
        _selectedTime =
            _parseTime(savedTime); // Chuyển đổi giờ lưu thành TimeOfDay
      });
    }
  }

  Future<void> _loadWateringTime1() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTime = prefs.getString('wateringTime');
    if (savedTime != null) {
      setState(() {
        _timeController1.text = savedTime;
        _selectedTime =
            _parseTime(savedTime); // Chuyển đổi giờ lưu thành TimeOfDay
      });
    }
  }

  Future<void> _saveWateringTime(String time) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('wateringTime', time);
  }

  Future<void> loadWateringTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimes = prefs.getStringList('wateringTimes');
    if (savedTimes != null) {
      wateringTimes =
          savedTimes.map((timeString) => DateTime.parse(timeString)).toList();
    }
    setState(() {});
  }

  Future<void> loadDateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDateTimeString = prefs.getString('lastDateTime');
    if (savedDateTimeString != null) {
      setState(() {
        _savedDateTime = DateTime.parse(savedDateTimeString);
      });
    }
  }

  Future<void> saveDateTime(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDateTime', dateTime.toIso8601String());
    setState(() {
      _savedDateTime = dateTime;
    });
  }

  void connectAndListen() {
    print('Call func connectAndListen');

    socket.onConnect((_) {
      print('connect');
      socket.emit('from-user', 'test from user');
    });

    socket.on('ServerToUser', (data) {
      print(data);
      var sensor = Sensor.fromJson(data);
      print('- Do am dat: ${sensor.data.soilhumidity}');
      setState(() {
        _sensorData = sensor;
      });
    });

    socket.on("AppUpdate", (data) {
      // Define the action for button press
      final now = DateTime.now();
      //final formattedDate =
      //DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
      wateringTimes.add(now);
      _saveWateringTimes(wateringTimes);
      // Notify the widget tree about the change
      setState(() {});
    });

    //When an event recieved from server, data is added to the stream
    socket.onDisconnect((_) => print('disconnect'));
  }

  void updateDate() {
    saveDateTime(DateTime.now());
    Fluttertoast.showToast(
      msg: "Đã cập nhật ngày tháng",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void WaterByHand() {
    socket.emit("WaterByHand");
  }

  void turningOnOff() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      on_off = !on_off;
      prefs.setBool('on_off', on_off); // Lưu trạng thái mới
      if (on_off == false) {
        socket.emit("TurnOnOff", "Off");
      } else {
        socket.emit("TurnOnOff", "On");
      }
    });
    print("Pushed");
    /*setState(() {
      if (on_off == false) {
        on_off = true;
        socket.emit("TurnOnOff", "On");
        print('Turn On');
      } else {
        on_off = false;
        socket.emit("TurnOnOff", "Off");
        print('Turn Off');
      }
    });*/
    if (on_off) {
      Fluttertoast.showToast(
        msg: "Hệ thống tưới nước tự động đã được bật",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 2,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Hệ thống tưới nước tự động đã được tắt",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 2,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _saveWateringTimes(List<DateTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedTimes = times.map((time) => time.toIso8601String()).toList();
    await prefs.setStringList('wateringTimes', encodedTimes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Smart Farming System',
            style: TextStyle(color: Color.fromARGB(255, 5, 255, 51))),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Card(
              color: Color.fromARGB(255, 5, 255, 51),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sensor',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 0, 0)),
                    ),
                    Padding(padding: EdgeInsets.all(4)),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: Color.fromARGB(255, 255, 0, 0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Soil Humidity',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white),
                                  ),
                                  Padding(padding: EdgeInsets.all(8)),
                                  Text(
                                    _sensorData.data.soilhumidity == null
                                        ? 'N/A'
                                        : '${double.parse(_sensorData.data.soilhumidity.toStringAsFixed(1))}%',
                                    style: TextStyle(
                                        fontSize: 40, color: Colors.white),
                                  ),
                                  Padding(padding: EdgeInsets.all(8)),
                                  Text(
                                    //'Ngày/Giờ: ${_savedDateTime?.toIso8601String() ?? 'Chưa lưu'}',
                                    DateFormat('EEEE, dd MMMM yyyy HH:mm', 'vi')
                                        .format(
                                            _savedDateTime ?? DateTime.now()),
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 150,
              alignment: Alignment.center,
              child: TextField(
                textAlign: TextAlign.center,
                controller: _timeController, // Điều khiển giá trị của ô nhập
                readOnly: true, // Không cho phép chỉnh sửa trực tiếp
                onTap: () => _selectTime(context), // Mở lịch khi nhấn vào
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    hintText: 'Chọn giờ', // Gợi ý cho người dùng
                    hintStyle: TextStyle(
                      color: Colors.black,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.elliptical(10, 20)))),
              ),
            ),
            Container(
              width: 150,
              alignment: Alignment.center,
              child: TextField(
                textAlign: TextAlign.center,
                controller: _timeController1, // Điều khiển giá trị của ô nhập
                readOnly: true, // Không cho phép chỉnh sửa trực tiếp
                onTap: () => _selectTime1(context), // Mở lịch khi nhấn vào
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                    hintText: 'Chọn giờ', // Gợi ý cho người dùng
                    hintStyle: TextStyle(
                      color: Colors.black,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.elliptical(10, 20)))),
              ),
            ),
            ElevatedButton(
              // Add the button here
              onPressed: WaterByHand,
              child: Text('Bấm vào đây để tưới cây thủ công'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.lock_clock), // Use calendar icon
                  onPressed: () {
                    _showHistoryDialog(context);
                  },
                ),
                Text('Lịch sử tưới', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: turningOnOff,
        child: Icon(
          on_off ? Icons.radio_button_on : Icons.radio_button_off,
        ),
        backgroundColor: Colors.white,
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Container(height: 50.0),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showHistoryDialog(BuildContext context) {
    // Implement the logic to display a dialog or another widget that
    // shows the history of saved dates and times.
    // You can use SharedPreferences to retrieve the saved data.

    // Example dialog structure (replace with your implementation)
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('LỊCH SỬ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: wateringTimes.map((dateTime) {
                return Text(DateFormat('dd/MM/yyyy HH:mm').format(dateTime));
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
}
