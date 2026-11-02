import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const PiskvorkyApp());
}

class PiskvorkyApp extends StatelessWidget {
  const PiskvorkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piškvorky 5-in-a-row',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  late IO.Socket socket;
  String nickname = "Player_${DateTime.now().millisecondsSinceEpoch % 1000}";
  bool isJumpscared = false;
  String roomCodeInput = "";
  String roomPasswordInput = "";

  final String serverUrl = "https://f4bcc4d5-02b7-4163-a367-192356831848-00-5kzxucfo3gcj.picard.replit.dev";
  final String customPath = "/api/socket.io";

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath(customPath)
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      socket.emit('login', {'nick': nickname});
    });

    socket.on('announcement', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ANNOUNCEMENT: ${data['message']}'), backgroundColor: Colors.orange),
      );
    });

    socket.on('trigger_jumpscare', (data) {
      if (data['targetNick'] == nickname || data['targetNick'] == 'ALL') {
        setState(() { isJumpscared = true; });
      }
    });

    socket.on('room_error', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room Error: ${data['message'] ?? 'Could not join room'}'), backgroundColor: Colors.red),
      );
    });
  }

  void createRoom() {
    if (roomCodeInput.trim().isEmpty) return;
    socket.emit('create_room', {
      'roomId': roomCodeInput.trim(),
      'password': roomPasswordInput.isEmpty ? null : roomPasswordInput,
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameGridScreen(
          socket: socket,
          nick: nickname,
          roomId: roomCodeInput.trim(),
        ),
      ),
    );
  }

  void joinRoom() {
    if (roomCodeInput.trim().isEmpty) return;
    socket.emit('join_room', {
      'roomId': roomCodeInput.trim(),
      'password': roomPasswordInput.isEmpty ? null : roomPasswordInput,
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameGridScreen(
          socket: socket,
          nick: nickname,
          roomId: roomCodeInput.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Piškvorky Tournament')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Your Nickname', border: OutlineInputBorder()),
                    onChanged: (val) {
                      nickname = val;
                      socket.emit('login', {'nick': val});
                    },
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Room Code (e.g. ROOM123)', border: OutlineInputBorder()),
                    onChanged: (val) => roomCodeInput = val,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Room Password (Optional)', border: OutlineInputBorder()),
                    obscureText: true,
                    onChanged: (val) => roomPasswordInput = val,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: createRoom,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Create Room'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: joinRoom,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          child: const Text('Join Room'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanelScreen(socket: socket))),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Admin Panel'),
                  ),
                ],
              ),
            ),
          ),
          if (isJumpscared)
            GestureDetector(
              onTap: () => setState(() { isJumpscared = false; }),
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning, color: Colors.red, size: 100),
                    Text('👻 BOO! ADMIN TROLLED YOU!', style: TextStyle(color: Colors.red, fontSize: 26, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Tap screen to dismiss', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

class GameGridScreen extends StatefulWidget {
  final IO.Socket socket;
  final String nick;
  final String roomId;
  const GameGridScreen({super.key, required this.socket, required this.nick, required this.roomId});

  @override
  State<GameGridScreen> createState() => _GameGridScreenState();
}

class _GameGridScreenState extends State<GameGridScreen> {
  List<List<String>> board = List.generate(15, (_) => List.generate(15, (_) => ''));
  int placedCount = 0;
  bool isSwapPhase = true;

  void handleTap(int r, int c) {
    if (board[r][c] != '') return;

    setState(() {
      if (isSwapPhase) {
        if (placedCount < 2) {
          board[r][c] = 'X';
        } else if (placedCount == 2) {
          board[r][c] = 'O';
          isSwapPhase = false;
        }
        placedCount++;
      } else {
        board[r][c] = 'X';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomId} ${isSwapPhase ? "(Swap Phase)" : ""}'),
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(15, (r) {
                return Row(
                  children: List.generate(15, (c) {
                    return GestureDetector(
                      onTap: () => handleTap(r, c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                        child: Center(
                          child: Text(
                            board[r][c],
                            style: TextStyle(
                              color: board[r][c] == 'X' ? Colors.blue : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPanelScreen extends StatefulWidget {
  final IO.Socket socket;
  const AdminPanelScreen({super.key, required this.socket});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String user = "";
  String pass = "";
  bool isAdmin = false;
  String targetNick = "ALL";
  String message = "";

  void login() {
    if (user == "admin" && pass == "admin1234") {
      setState(() { isAdmin = true; });
      widget.socket.emit('admin_login', {'nick': user, 'pass': pass});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Credentials!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Controls')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !isAdmin
            ? Column(
                children: [
                  TextField(decoration: const InputDecoration(labelText: 'Admin Username'), onChanged: (v) => user = v),
                  TextField(decoration: const InputDecoration(labelText: 'Admin Password'), obscureText: true, onChanged: (v) => pass = v),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: login, child: const Text('Login')),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Admin Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(decoration: const InputDecoration(labelText: 'Target Nick (or ALL)'), onChanged: (v) => targetNick = v),
                  ElevatedButton(
                    onPressed: () => widget.socket.emit('admin_jumpscare', {'targetNick': targetNick}),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    child: const Text('Trigger Jumpscare 👻'),
                  ),
                  const SizedBox(height: 15),
                  TextField(decoration: const InputDecoration(labelText: 'Announcement Text'), onChanged: (v) => message = v),
                  ElevatedButton(
                    onPressed: () => widget.socket.emit('admin_broadcast', {'message': message}),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Send Global Announcement 📢'),
                  ),
                ],
              ),
      ),
    );
  }
}
