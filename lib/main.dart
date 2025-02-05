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

  void _deleteCategory(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar categoría'),
          content: Text('¿Estás seguro de que quieres eliminar la categoría "${categories[index]['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        categories.removeAt(index);
      });
    }
  }

  void _editCategory(int index) {
    final controller = TextEditingController(text: categories[index]['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar categoría'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Nuevo nombre de la categoría'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    categories[index]['name'] = controller.text;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
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

  void _newSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nueva sesión'),
          content: Text('¿Estás seguro de que quieres comenzar una nueva sesión? Se guardará la sesión actual.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _saveSession();
      if (mounted) {
        setState(() {
          categories.clear();
        });
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Información de la aplicación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('cuentaGanado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Una app para contar todo lo que quieras...'),
              SizedBox(height: 10),
              Text('Versión: 1.0.0'),
              SizedBox(height: 10),
              Text('Desarrollado por: [Rafael A. Jiménez]'),
              SizedBox(height: 10),
              Text('Contacto: [x.com/@leCrancWD]'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
          value: 'new',
          child: Text('Nueva sesión'),
        ),
        PopupMenuItem(
          value: 'share',
          child: Text('Compartir sesión'),
        ),
        PopupMenuItem(
          value: 'about',
          child: Text('Información'),
        ),
      ],
    ).then((value) {
      if (value == 'save') {
        _saveSession();
      } else if (value == 'read') {
        _readSessions();
      } else if (value == 'new') {
        _newSession();
      } else if (value == 'share') {
        _shareSession();
      } else if (value == 'about') {
        _showAboutDialog();
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
                          children: [
                            // Nombre de la categoría
                            Text(
                              categories[index]['name'],
                              style: TextStyle(fontSize: 18),
                            ),
                            // Botones de editar y borrar
                            IconButton(
                              icon: Icon(Icons.edit, size: 20),
                              onPressed: () => _editCategory(index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _deleteCategory(index),
                            ),
                            // Espacio restante
                            Spacer(),
                            // Botones de sumar, restar y conteo
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