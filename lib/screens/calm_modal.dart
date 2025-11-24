import 'dart:async';
import 'package:flutter/material.dart';
import 'package:clareza_diaria/services/api_service.dart';

class CalmModal extends StatefulWidget {
  final String userName;
  final int userId;

  const CalmModal({
    Key? key,
    required this.userName,
    required this.userId,
  }) : super(key: key);

  @override
  State<CalmModal> createState() => _CalmModalState();
}

class _CalmModalState extends State<CalmModal> {
  int _breathCount = 0;
  int _currentPhase = 0; // 0: INSPIRE, 1: EXPIRE
  int _secondsRemaining = 4;
  Timer? _timer;
  bool _isActive = false;
  bool _isComplete = false;

  final List<String> _phases = ['Inspire', 'Expire'];
  final List<int> _durations = [4, 4]; // 4 SEGUNDOS INSPIRE, 4 SEGUNDOS EXPIRE

  @override
  void initState() {
    super.initState();
    _sendHelpNotification();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendHelpNotification() async {
    try {
      await ApiService.requestHelp(userId: widget.userId);
    } catch (e) {
      // SILENCIOSAMENTE FALHA - NÃO QUEREMOS INTERROMPER A EXPERIÊNCIA DE CALMA
      print('Erro ao enviar notificação de ajuda: $e');
    }
  }

  void _startBreathing() {
    setState(() {
      _isActive = true;
      _breathCount = 0;
      _currentPhase = 0;
      _secondsRemaining = _durations[0];
    });
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    setState(() {
      _currentPhase++;
      if (_currentPhase >= _phases.length) {
        // CICLO COMPLETO
        _breathCount++;
        _currentPhase = 0;
        
        if (_breathCount >= 3) {
          // COMPLETOU 3 CICLOS
          _timer?.cancel();
          _isComplete = true;
          _isActive = false;
          return;
        }
      }
      _secondsRemaining = _durations[_currentPhase];
    });
  }

  void _stopBreathing() {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _breathCount = 0;
      _currentPhase = 0;
      _secondsRemaining = 4;
      _isComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!.withOpacity(0.95),
              Colors.black.withOpacity(0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // ÍCONE DE CALMA
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue[700]!.withOpacity(0.3),
                  ),
                  child: const Icon(
                    Icons.spa,
                    size: 40,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 32),
                // MENSAGEM PRINCIPAL
                Text(
                  'Você não está sozinho(a).\nTudo vai passar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Que tal uma técnica de respiração\npara se acalmar?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),
                // INSTRUÇÕES
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInstruction('Inspire pelo nariz por 4 segundos'),
                      const SizedBox(height: 12),
                      _buildInstruction('Solte o ar lentamente por 4 segundos'),
                      const SizedBox(height: 12),
                      _buildInstruction('Repita 3 vezes'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // ÁREA DE RESPIRAÇÃO
                if (_isActive && !_isComplete) ...[
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getPhaseColor().withOpacity(0.3),
                      border: Border.all(
                        color: _getPhaseColor(),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _phases[_currentPhase],
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_secondsRemaining',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _getPhaseColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ciclo ${_breathCount + 1} de 3',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _stopBreathing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Parar'),
                  ),
                ] else if (_isComplete) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[700]!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green[400]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Você está fazendo o seu melhor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cada respiração ajuda seu corpo a voltar ao equilíbrio. Confie no seu ritmo — você é capaz!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _startBreathing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Começar Respiração',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                // BOTÃO DE FECHAR (QUANDO NÃO ESTÁ ATIVO)
                if (!_isActive && !_isComplete)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Fechar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 12),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueAccent,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case 0: // INSPIRE
        return Colors.blueAccent;
      case 1: // EXPIRE
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }
}

