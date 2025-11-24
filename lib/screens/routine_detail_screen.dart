import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/routine.dart';
import '../services/api_service.dart';

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.initialRoutine, this.isProfissional = false});

  final RoutineModel initialRoutine;
  final bool isProfissional;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late RoutineModel _routine;
  late TextEditingController _tituloController;
  late TextEditingController _horarioController;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _routine = widget.initialRoutine.copy();
    _tituloController = TextEditingController(text: _routine.titulo);
    _horarioController = TextEditingController(text: _routine.lembrete ?? '');
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um título para a rotina.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final response = await ApiService.updateRoutine(
      routineId: _routine.id,
      titulo: titulo,
      lembrete: _horarioController.text.trim().isEmpty
          ? null
          : _horarioController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (response['success'] == true) {
      _routine.titulo = titulo;
      _routine.lembrete = _horarioController.text.trim().isEmpty
          ? null
          : _horarioController.text.trim();
      _changed = true;
      if (mounted) {
        // Aguardar um frame antes de fazer pop para garantir que o estado foi atualizado
        await Future.delayed(const Duration(milliseconds: 50));
        Navigator.of(context).pop(true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Não foi possível salvar a rotina.'),
        ),
      );
    }
  }

  Future<void> _addStep() async {
    final data = await showDialog<_StepDialogData>(
      context: context,
      builder: (context) => const _StepDialog(),
    );

    if (data == null) return;

    final response = await ApiService.addRoutineStep(
      routineId: _routine.id,
      descricao: data.descricao,
      duracao: data.duracao,
      ordem: _routine.passos.length,
    );

    if (!mounted) return;

    if (response['success'] == true && response['data'] is Map<String, dynamic>) {
      final newStep = RoutineStepModel.fromJson(response['data'] as Map<String, dynamic>);
      setState(() {
        _routine.passos.add(newStep);
        _changed = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Erro ao adicionar passo.'),
        ),
      );
    }
  }

  Future<void> _editStep(RoutineStepModel step) async {
    final data = await showDialog<_StepDialogData>(
      context: context,
      builder: (context) => _StepDialog(existing: step),
    );

    if (data == null) return;

    final response = await ApiService.updateRoutineStep(
      routineId: _routine.id,
      stepId: step.id,
      descricao: data.descricao,
      duracao: data.duracao,
    );

    if (!mounted) return;

    if (response['success'] == true && response['data'] is Map<String, dynamic>) {
      setState(() {
        step.descricao = data.descricao;
        step.duracao = data.duracao;
        _changed = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Erro ao atualizar o passo.'),
        ),
      );
    }
  }

  Future<void> _deleteStep(RoutineStepModel step) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover passo'),
        content: Text('Deseja remover "${step.descricao}" da rotina?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await ApiService.deleteRoutineStep(
      routineId: _routine.id,
      stepId: step.id,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _routine.passos.removeWhere((element) => element.id == step.id);
        _changed = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Erro ao remover o passo.'),
        ),
      );
    }
  }

  void _toggleStepCompletion(RoutineStepModel step, bool? value) {
    setState(() {
      step.concluido = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalConcluidos = _routine.passos.where((step) => step.concluido).length;
    final totalPassos = _routine.passos.length;

    return WillPopScope(
      onWillPop: () async {
        // Não fazer pop aqui, deixar o botão "voltar" fazer isso
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Voltar para a lista de rotinas
                            Navigator.of(context).pop(_changed);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1EC7A5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Voltar'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _tituloController,
                            enabled: !widget.isProfissional,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                     (Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : const Color(0xFF1E1E1E)),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Título da rotina',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalConcluidos de $totalPassos atividades completadas',
                          style: TextStyle(
                            fontSize: 14, 
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                   (Theme.of(context).brightness == Brightness.dark 
                                    ? const Color(0xFFB0B4C1) 
                                    : const Color(0xFF6B7280)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _horarioController,
                          enabled: !widget.isProfissional,
                          decoration: const InputDecoration(
                            labelText: 'Horário (ex: 07:00)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: _routine.passos.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _routine.passos.length) {
                          return widget.isProfissional
                              ? const SizedBox.shrink()
                              : _AddStepCard(onTap: _addStep);
                        }
                        final step = _routine.passos[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StepCard(
                            step: step,
                            onChanged: widget.isProfissional ? null : (value) => _toggleStepCompletion(step, value),
                            onEdit: widget.isProfissional ? null : () => _editStep(step),
                            onDelete: widget.isProfissional ? null : () => _deleteStep(step),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (!widget.isProfissional)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveRoutine,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF1EC7A5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Salvar rotina',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (_saving)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    this.onChanged,
    this.onEdit,
    this.onDelete,
  });

  final RoutineStepModel step;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: step.concluido, onChanged: onChanged),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.descricao,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? 
                           (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : const Color(0xFF1E1E1E)),
                  ),
                ),
                if (step.duracao != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${step.duracao} min',
                      style: TextStyle(
                        fontSize: 13, 
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                               (Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFFB0B4C1) 
                                : const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1EC7A5)),
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
            ),
        ],
      ),
    );
  }
}

class _AddStepCard extends StatelessWidget {
  const _AddStepCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1EC7A5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '+ Adicionar passo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1EC7A5),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDialogData {
  const _StepDialogData({required this.descricao, this.duracao});

  final String descricao;
  final int? duracao;
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({this.existing});

  final RoutineStepModel? existing;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late TextEditingController _descricaoController;
  late TextEditingController _duracaoController;
  String? _descricaoError;

  @override
  void initState() {
    super.initState();
    _descricaoController = TextEditingController(text: widget.existing?.descricao ?? '');
    _duracaoController = TextEditingController(
      text: widget.existing?.duracao != null ? widget.existing!.duracao.toString() : '',
    );
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(isEditing ? 'Editar passo' : 'Novo passo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _descricaoController,
            decoration: InputDecoration(
              labelText: 'Descrição',
              border: const OutlineInputBorder(),
              errorText: _descricaoError,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duracaoController,
            decoration: const InputDecoration(
              labelText: 'Duração (min)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final descricao = _descricaoController.text.trim();
            if (descricao.isEmpty) {
              setState(() {
                _descricaoError = 'Informe um texto para o passo';
              });
              return;
            }

            final duracaoText = _duracaoController.text.trim();
            final duracao = duracaoText.isEmpty ? null : int.tryParse(duracaoText);

            Navigator.of(context).pop(
              _StepDialogData(descricao: descricao, duracao: duracao),
            );
          },
          child: Text(isEditing ? 'Atualizar' : 'Adicionar'),
        ),
      ],
    );
  }
}
