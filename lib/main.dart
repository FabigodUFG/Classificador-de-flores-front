import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classificador de Imagens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Classificador de Imagens'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? _selectedImageBytes; // Armazena os bytes da imagem
  String _statusMessage = ''; // Armazena o status da ação
  String? _classification; // Resultado da classificação
  bool _isLoading = false; // Indicador de carregamento

  // Função para selecionar a imagem
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result == null) {
        setState(() {
          _statusMessage = 'Nenhuma imagem selecionada.';
        });
        return;
      }

      // Obtemos os bytes do arquivo selecionado
      final imageBytes = result.files.single.bytes;

      if (imageBytes == null) {
        setState(() {
          _statusMessage = 'Erro ao ler o conteúdo da imagem.';
        });
        return;
      }

      setState(() {
        _selectedImageBytes = imageBytes; // Armazena os bytes da imagem
        _statusMessage = 'Imagem selecionada com sucesso!';
      });
    } catch (e) {
      print("Erro ao selecionar a imagem: $e");
      setState(() {
        _statusMessage = 'Erro ao selecionar a imagem.';
      });
    }
  }

  // Função para enviar a imagem para a API
  Future<void> _sendImage() async {
    if (_selectedImageBytes == null) {
      setState(() {
        _statusMessage = 'Por favor, selecione uma imagem primeiro.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Enviando imagem para classificação...';
    });

    String ip = 'localhost'; // IP  127.0.0.1:5000
    String port = '8089';
    String endpoint = '/classify';

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://$ip:$port$endpoint'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          _selectedImageBytes!,
          filename: 'image.jpg',
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();

        // Decodifica a resposta JSON
        final responseData = jsonDecode(responseBody);

        String predictClass = responseData['class'];
        double accuracy = responseData['confidence'];

        setState(() {
          _classification = "Classificação: $predictClass\nPrecisão: ${accuracy.toStringAsFixed(2)}%";
          _statusMessage = 'Classificação realizada com sucesso!';
        });
      } else {
        setState(() {
          _statusMessage = 'Erro ao classificar a imagem: ${response.statusCode}';
        });
      }
    } catch (e) {
      print("Erro ao enviar requisição: $e");
      setState(() {
        _statusMessage = 'Erro ao classificar a imagem.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Verifica se a imagem foi selecionada para exibir
            if (_selectedImageBytes != null)
              Image.memory(
                _selectedImageBytes!, // Exibe a imagem a partir dos bytes
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 20),
            // Botão para selecionar a imagem
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Selecionar Imagem'),
            ),
            const SizedBox(height: 20),
            // Botão para enviar a imagem
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _sendImage,
                child: const Text('Classificar Imagem'),
              ),
            const SizedBox(height: 20),
            // Exibe a mensagem de status ou classificação
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_classification != null) ...[
              const SizedBox(height: 20),
              Text(
                _classification!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
