import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String _cleanNotificationMessage(String mensagem) {
    // REMOVER IDs TÉCNICOS DA MENSAGEM (TUDO APÓS |||)
    return mensagem.split('|||').first.trim();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.listNotifications();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final notifications = List<Map<String, dynamic>>.from(
        (result['data'] as List).whereType<Map<String, dynamic>>(),
      );
      
      // Se alguma notificação de care_link_request não tiver care_link_id, buscar pelos vínculos
      for (var notif in notifications) {
        if (notif['tipo'] == 'care_link_request' && notif['care_link_id'] == null) {
          // Buscar o care_link_id através da lista de vínculos
          final careLinksResult = await ApiService.listCareLinks();
          if (careLinksResult['success'] == true && careLinksResult['data'] is List) {
            final careLinks = List<Map<String, dynamic>>.from(
              (careLinksResult['data'] as List).whereType<Map<String, dynamic>>(),
            );
            // Procurar um vínculo pendente (assumindo que é o mais recente)
            final pendingLink = careLinks.firstWhere(
              (link) => link['status'] == 'pending',
              orElse: () => <String, dynamic>{},
            );
            if (pendingLink.isNotEmpty && pendingLink['id'] != null) {
              notif['care_link_id'] = pendingLink['id'];
            }
          }
        }
      }
      
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Não foi possível carregar as notificações.';
      });
    }
  }

  Future<void> _respondToCareLink(int careLinkId, bool accept) async {
    final result = await ApiService.respondCareLink(
      careLinkId: careLinkId,
      accept: accept,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Solicitação aceita com sucesso!' : 'Solicitação rejeitada.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Erro ao responder solicitação',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _respondToShare(int notificationId, bool accept) async {
    final result = await ApiService.respondShare(
      shareId: notificationId, // BACKEND AGORA ESPERA notification_id NO LUGAR DE share_id
      accept: accept,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Acesso concedido com sucesso!' : 'Acesso negado.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Erro ao responder solicitação',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResponseDialog(int careLinkId, String cuidadorNome) {
    if (!mounted) return;
    
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Vínculo'),
          content: Text(
            '$cuidadorNome deseja se vincular como seu cuidador. Deseja aceitar?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _respondToCareLink(careLinkId, false);
              },
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _respondToCareLink(careLinkId, true);
              },
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
  }

  void _showShareResponseDialog(int notificationId, String profissionalNome) {
    if (!mounted) return;
    
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Acesso'),
          content: Text(
            '$profissionalNome deseja acessar seus relatórios e rotinas. Deseja permitir?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _respondToShare(notificationId, false);
              },
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _respondToShare(notificationId, true);
              },
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back, 
            color: Theme.of(context).iconTheme.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notificações',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                       (Theme.of(context).brightness == Brightness.dark 
                                        ? const Color(0xFFB0B4C1) 
                                        : const Color(0xFF6B7280)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadNotifications,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 100),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma notificação',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Você não tem notificações no momento',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            final isUnread = !(notif['lida'] ?? false);
                            final tipo = notif['tipo'] as String? ?? '';
                            // Converter care_link_id para int, pode vir como int ou string
                            int? careLinkId;
                            final careLinkIdValue = notif['care_link_id'];
                            if (careLinkIdValue != null) {
                              if (careLinkIdValue is int) {
                                careLinkId = careLinkIdValue;
                              } else if (careLinkIdValue is String) {
                                careLinkId = int.tryParse(careLinkIdValue);
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Theme.of(context).colorScheme.surface,
                              child: InkWell(
                                onTap: () {
                                  // Se for solicitação de vínculo, abrir modal de confirmação
                                  if (tipo == 'care_link_request' && careLinkId != null) {
                                    final mensagem = notif['mensagem'] as String? ?? '';
                                    // Extrair nome do cuidador da mensagem
                                    final match = RegExp(r'^(.+?) deseja').firstMatch(mensagem);
                                    final cuidadorNome = match?.group(1) ?? 'Alguém';
                                    
                                    // Marcar como lida (não esperar)
                                    if (isUnread && notif['id'] != null) {
                                      ApiService.markNotificationRead(
                                        notificationId: notif['id'] as int,
                                      );
                                    }
                                    
                                    // Abrir modal de confirmação imediatamente
                                    _showResponseDialog(careLinkId, cuidadorNome);
                                  } else if (tipo == 'share_request') {
                                    final mensagem = notif['mensagem'] as String? ?? '';
                                    // Remover IDs técnicos da mensagem (tudo após |||)
                                    final mensagemLimpa = mensagem.split('|||').first;
                                    // Extrair nome do profissional da mensagem
                                    final match = RegExp(r'^(.+?) \(').firstMatch(mensagemLimpa);
                                    final profissionalNome = match?.group(1) ?? 'Profissional';
                                    
                                    // USAR O ID DA NOTIFICAÇÃO, NÃO O share_id
                                    final notificationId = notif['id'] as int?;
                                    if (notificationId == null) return;
                                    
                                    // NÃO MARCAR COMO LIDA AINDA - SÓ MARCA DEPOIS DE RESPONDER
                                    // A notificação será marcada como lida no backend quando for respondida
                                    
                                    // Abrir modal de confirmação imediatamente
                                    _showShareResponseDialog(notificationId, profissionalNome);
                                  } else {
                                    // Para outras notificações, apenas marcar como lida
                                    if (isUnread && notif['id'] != null) {
                                      ApiService.markNotificationRead(
                                        notificationId: notif['id'] as int,
                                      ).then((_) {
                                        if (mounted) {
                                          _loadNotifications();
                                        }
                                      });
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isUnread
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                    child: Icon(
                                      tipo == 'care_link_request'
                                          ? Icons.person_add
                                          : tipo == 'care_link_accepted'
                                              ? Icons.check_circle
                                              : Icons.notifications,
                                      color: isUnread ? Colors.white : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    notif['titulo'] as String? ?? 'Notificação',
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                             (Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.white 
                                              : const Color(0xFF2F2F2F)),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        _cleanNotificationMessage(notif['mensagem'] as String? ?? ''),
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                                 (Theme.of(context).brightness == Brightness.dark 
                                                  ? const Color(0xFFB0B4C1) 
                                                  : const Color(0xFF6B7280)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isUnread
                                      ? Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: Theme.of(context).colorScheme.primary,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          // Navegar de volta para a home com o índice selecionado
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          Navigator.of(context).pushReplacementNamed(
            '/home',
            arguments: {
              ...?args,
              'selectedIndex': index,
            },
          );
        },
        selectedItemColor: const Color(0xFF5C6EF8),
        unselectedItemColor: const Color(0xFFB0B4C1),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Diário',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            label: 'Rotina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Relatório',
          ),
        ],
      ),
    );
  }
}

