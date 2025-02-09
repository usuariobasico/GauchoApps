import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart'; // Para usar Clipboard
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart'; // Para la web

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cuentaGanado',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: CounterScreen(),
    );
  }
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  _CounterScreenState createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  List<Map<String, dynamic>> categories = [];
  List<String> allCategories = [];
  String? _saveSessionMessage;
  bool isDarkMode = false;

  // Clave global para el ScaffoldMessenger
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  void _addCategory(String name) {
    setState(() {
      categories.add({'name': name, 'count': 0});
      if (!allCategories.contains(name)) {
        allCategories.add(name);
      }
    });
  }

  void _incrementCounter(int index) {
    setState(() {
      categories[index]['count']++;
    });
  }

  void _decrementCounter(int index) {
    setState(() {
      if (categories[index]['count'] > 0) {
        categories[index]['count']--;
      }
    });
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Agregar categoría'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(hintText: 'Nombre de la categoría'),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  if (controller.text.isNotEmpty)
                    ...getSuggestions(controller.text).map((suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                        onTap: () {
                          controller.text = suggestion;
                          setState(() {});
                        },
                      );
                    }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      _addCategory(controller.text);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> getSuggestions(String query) {
    return allCategories
        .where((category) => category.toLowerCase().contains(query.toLowerCase()))
        .take(3)
        .toList();
  }

  int _getTotalCount() {
    return categories.fold(0, (sum, category) => sum + (category['count'] as int));
  }

  Future<void> _saveSession() async {
    try {
      if (kIsWeb) {
        // En la web, usamos SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sesion', jsonEncode(categories));
        if (mounted) {
          setState(() {
            _saveSessionMessage = 'Sesión guardada correctamente (web)';
          });
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(_saveSessionMessage!)),
          );
        }
      } else {
        // En otras plataformas, usamos path_provider
        final directory = await getApplicationDocumentsDirectory();
        final sessionsDir = Directory('${directory.path}/sessions');

        if (!await sessionsDir.exists()) {
          await sessionsDir.create(recursive: true);
        }

        final fileName = 'session_${DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '')}.json';
        final file = File('${sessionsDir.path}/$fileName');
        await file.writeAsString(jsonEncode(categories));

        if (mounted) {
          setState(() {
            _saveSessionMessage = 'Sesión guardada correctamente';
          });
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(_saveSessionMessage!)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveSessionMessage = 'Error al guardar la sesión: $e';
        });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(_saveSessionMessage!)),
        );
      }
    }
  }

  Future<void> _readSessions() async {
    try {
      if (kIsWeb) {
        // En la web, usamos SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final sesion = prefs.getString('sesion');

        if (sesion != null) {
          final data = jsonDecode(sesion) as List<dynamic>;
          if (mounted) {
            setState(() {
              categories = List<Map<String, dynamic>>.from(data);
              _saveSessionMessage = 'Sesión cargada correctamente (web)';
            });
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(_saveSessionMessage!)),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _saveSessionMessage = 'No se encontró ninguna sesión guardada (web)';
            });
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(_saveSessionMessage!)),
            );
          }
        }
      } else {
        // En otras plataformas, usamos file_picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (result != null) {
          final file = File(result.files.single.path!);
          final content = await file.readAsString();
          final data = jsonDecode(content) as List<dynamic>;

          if (mounted) {
            setState(() {
              categories = List<Map<String, dynamic>>.from(data);
              _saveSessionMessage = 'Sesión cargada correctamente';
            });
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(_saveSessionMessage!)),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _saveSessionMessage = 'No se seleccionó ningún archivo';
            });
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(_saveSessionMessage!)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveSessionMessage = 'Error al leer la sesión: $e';
        });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(_saveSessionMessage!)),
        );
      }
    }
  }

  Future<void> _shareSession() async {
    try {
      final sessionData = 'Sesión ${DateTime.now()}\nTotal: ${_getTotalCount()}\n${categories.map((cat) => '${cat['name']}: ${cat['count']}').join('\n')}';

      if (kIsWeb || Platform.isWindows) {
        await Clipboard.setData(ClipboardData(text: sessionData));
        if (mounted) {
          setState(() {
            _saveSessionMessage = 'Sesión copiada al portapapeles';
          });
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(_saveSessionMessage!)),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/session_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsString(jsonEncode(categories));

        await Share.shareFiles([file.path], text: sessionData);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveSessionMessage = 'Error al compartir la sesión: $e';
        });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(_saveSessionMessage!)),
        );
      }
    }
  }

  void _showMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(0, kToolbarHeight, 0, 0),
      items: [
        PopupMenuItem(
          value: 'save',
          child: Text('Guardar sesión'),
        ),
        PopupMenuItem(
          value: 'read',
          child: Text('Leer sesión'),
        ),
        PopupMenuItem(
          value: 'share',
          child: Text('Compartir sesión'),
        ),
      ],
    ).then((value) {
      if (value == 'save') {
        _saveSession();
      } else if (value == 'read') {
        _readSessions();
      } else if (value == 'share') {
        _shareSession();
      }
    });
  }

  void toggleDarkMode() {
    if (mounted) {
      setState(() {
        isDarkMode = !isDarkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: Text('cuentaGanado'),
            leading: IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => _showMenu(context),
            ),
            actions: [
              IconButton(
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: toggleDarkMode,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Total: ${_getTotalCount()}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              categories[index]['name'],
                              style: TextStyle(fontSize: 18),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove, size: 30),
                                  onPressed: () => _decrementCounter(index),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  categories[index]['count'].toString(),
                                  style: TextStyle(fontSize: 24),
                                ),
                                SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(Icons.add, size: 30),
                                  onPressed: () => _incrementCounter(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _showAddCategoryDialog,
                  child: Text('+ Agregar Categoria'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}