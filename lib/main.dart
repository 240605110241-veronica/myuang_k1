import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyUangApp());
}

class MyUangApp extends StatelessWidget {
  const MyUangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// MODEL TRANSAKSI
// ============================================================

class TransactionModel {
  final String id;
  final String type;
  final String category;
  final double amount;
  final String note;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      type: json['type'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<TransactionModel> transactions = [];
  double monthlyBudget = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final transactionData = prefs.getString('transactions');
    final budgetData = prefs.getDouble('monthly_budget');

    List<TransactionModel> loadedTransactions = [];

    if (transactionData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(transactionData);

        loadedTransactions = decoded
            .map(
              (item) => TransactionModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
            .toList();
      } catch (_) {
        loadedTransactions = [];
      }
    }

    if (!mounted) return;

    setState(() {
      transactions = loadedTransactions;
      monthlyBudget = budgetData ?? 0;
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final data = transactions.map((item) => item.toJson()).toList();

    await prefs.setString('transactions', jsonEncode(data));
  }

  Future<void> _saveBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', budget);
  }

  double get totalIncome {
    return transactions
        .where((item) => item.type == 'Pemasukan')
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get totalExpense {
    return transactions
        .where((item) => item.type == 'Pengeluaran')
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get balance {
    return totalIncome - totalExpense;
  }

  void _addTransaction(TransactionModel transaction) {
    setState(() {
      transactions.insert(0, transaction);
    });

    _saveTransactions();
  }

  void _updateTransaction(TransactionModel updated) {
    setState(() {
      final index = transactions.indexWhere(
            (item) => item.id == updated.id,
      );

      if (index != -1) {
        transactions[index] = updated;
      }
    });

    _saveTransactions();
  }

  void _deleteTransaction(String id) {
    setState(() {
      transactions.removeWhere((item) => item.id == id);
    });

    _saveTransactions();
  }

  Future<void> _showAddTransaction() async {
    final result = await Navigator.push<TransactionModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const TransactionFormPage(),
      ),
    );

    if (!mounted || result == null) return;

    _addTransaction(result);
  }

  Future<void> _showEditTransaction(TransactionModel transaction) async {
    final result = await Navigator.push<TransactionModel>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormPage(
          transaction: transaction,
        ),
      ),
    );

    if (!mounted || result == null) return;

    _updateTransaction(result);
  }

  void _deleteWithConfirmation(TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Transaksi'),
          content: const Text(
            'Apakah kamu yakin ingin menghapus transaksi ini?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteTransaction(transaction.id);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        transactions: transactions,
        balance: balance,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        onAddTransaction: _showAddTransaction,
      ),
      TransactionListPage(
        transactions: transactions,
        onEdit: _showEditTransaction,
        onDelete: _deleteWithConfirmation,
        onAdd: _showAddTransaction,
      ),
      StatisticsPage(
        transactions: transactions,
      ),
      BudgetPage(
        transactions: transactions,
        monthlyBudget: monthlyBudget,
        onBudgetChanged: (value) {
          setState(() {
            monthlyBudget = value;
          });

          _saveBudget(value);
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  final List<TransactionModel> transactions;
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final VoidCallback onAddTransaction;

  const DashboardPage({
    super.key,
    required this.transactions,
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.onAddTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final recentTransactions = transactions.take(5).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MyUang',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kelola keuangan pribadi dengan lebih teratur.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // SALDO
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo Saat Ini',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRupiah(balance),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PEMASUKAN DAN PENGELUARAN
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Pemasukan',
                    amount: totalIncome,
                    icon: Icons.arrow_downward,
                    iconColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Pengeluaran',
                    amount: totalExpense,
                    icon: Icons.arrow_upward,
                    iconColor: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddTransaction,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Transaksi'),
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Transaksi Terbaru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (recentTransactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tambahkan transaksi pertama kamu.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...recentTransactions.map(
                    (transaction) => TransactionTile(
                  transaction: transaction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SUMMARY CARD
// ============================================================

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color iconColor;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TRANSACTION LIST
// ============================================================

class TransactionListPage extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onEdit;
  final Function(TransactionModel) onDelete;
  final VoidCallback onAdd;

  const TransactionListPage({
    super.key,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  String filter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = widget.transactions.where((transaction) {
      if (filter == 'Semua') return true;
      return transaction.type == filter;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Semua Transaksi',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_circle),
                  iconSize: 32,
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: filter == 'Semua',
                  onSelected: (_) {
                    setState(() {
                      filter = 'Semua';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pemasukan'),
                  selected: filter == 'Pemasukan',
                  onSelected: (_) {
                    setState(() {
                      filter = 'Pemasukan';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pengeluaran'),
                  selected: filter == 'Pengeluaran',
                  onSelected: (_) {
                    setState(() {
                      filter = 'Pengeluaran';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: filteredTransactions.isEmpty
                ? const Center(
              child: Text(
                'Tidak ada transaksi.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final transaction = filteredTransactions[index];

                return TransactionTile(
                  transaction: transaction,
                  onTap: () {
                    showTransactionDetail(
                      context,
                      transaction,
                      widget.onEdit,
                      widget.onDelete,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TRANSACTION TILE
// ============================================================

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'Pemasukan';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          ),
        ),
        title: Text(
          transaction.category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          transaction.note.isEmpty
              ? 'Tanpa catatan'
              : transaction.note,
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${formatRupiah(transaction.amount)}',
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL TRANSAKSI
// ============================================================

void showTransactionDetail(
    BuildContext context,
    TransactionModel transaction,
    Function(TransactionModel) onEdit,
    Function(TransactionModel) onDelete,
    ) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Transaksi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            DetailRow(
              label: 'Jenis',
              value: transaction.type,
            ),
            DetailRow(
              label: 'Kategori',
              value: transaction.category,
            ),
            DetailRow(
              label: 'Jumlah',
              value: formatRupiah(transaction.amount),
            ),
            DetailRow(
              label: 'Catatan',
              value: transaction.note.isEmpty
                  ? 'Tanpa catatan'
                  : transaction.note,
            ),
            DetailRow(
              label: 'Tanggal',
              value: formatDate(transaction.date),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onEdit(transaction);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onDelete(transaction);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORM TRANSAKSI
// ============================================================

class TransactionFormPage extends StatefulWidget {
  final TransactionModel? transaction;

  const TransactionFormPage({
    super.key,
    this.transaction,
  });

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late String selectedType;
  late String selectedCategory;

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  final incomeCategories = [
    'Gaji',
    'Bonus',
    'Hadiah',
    'Lainnya',
  ];

  final expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Pendidikan',
    'Kesehatan',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    selectedType = transaction?.type ?? 'Pengeluaran';

    selectedCategory =
        transaction?.category ??
            (selectedType == 'Pemasukan'
                ? incomeCategories.first
                : expenseCategories.first);

    if (transaction != null) {
      amountController.text = transaction.amount.toStringAsFixed(0);
      noteController.text = transaction.note;
      selectedDate = transaction.date;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  List<String> get categories {
    return selectedType == 'Pemasukan'
        ? incomeCategories
        : expenseCategories;
  }

  void _changeType(String? value) {
    if (value == null) return;

    setState(() {
      selectedType = value;

      if (!categories.contains(selectedCategory)) {
        selectedCategory = categories.first;
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) return;

    setState(() {
      selectedDate = picked;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(
      amountController.text.replaceAll('.', ''),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    final transaction = TransactionModel(
      id: widget.transaction?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: selectedType,
      category: selectedCategory,
      amount: amount,
      note: noteController.text.trim(),
      date: selectedDate,
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Transaksi' : 'Tambah Transaksi',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Jenis Transaksi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.swap_vert),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Pemasukan',
                  child: Text('Pemasukan'),
                ),
                DropdownMenuItem(
                  value: 'Pengeluaran',
                  child: Text('Pengeluaran'),
                ),
              ],
              onChanged: _changeType,
            ),

            const SizedBox(height: 20),

            const Text(
              'Jumlah',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
                hintText: 'Contoh: 50000',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jumlah harus diisi';
                }

                final amount = double.tryParse(
                  value.replaceAll('.', ''),
                );

                if (amount == null || amount <= 0) {
                  return 'Masukkan angka yang valid';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'Kategori',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'Catatan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Tambahkan catatan...',
                prefixIcon: Icon(Icons.notes),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Tanggal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(
                  formatDate(selectedDate),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(
                  isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATISTIK
// ============================================================

class StatisticsPage extends StatelessWidget {
  final List<TransactionModel> transactions;

  const StatisticsPage({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = transactions
        .where((item) => item.type == 'Pengeluaran')
        .toList();

    final Map<String, double> categoryTotals = {};

    for (final transaction in expenses) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) +
              transaction.amount;
    }

    final totalExpense = expenses.fold<double>(
      0,
          (sum, item) => sum + item.amount,
    );

    String biggestCategory = '-';
    double biggestAmount = 0;

    for (final entry in categoryTotals.entries) {
      if (entry.value > biggestAmount) {
        biggestAmount = entry.value;
        biggestCategory = entry.key;
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistik Keuangan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Pengeluaran',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRupiah(totalExpense),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Pengeluaran Berdasarkan Kategori',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (categoryTotals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada pengeluaran yang cukup untuk membuat statistik.',
                  ),
                ),
              )
            else
              ...categoryTotals.entries.map(
                    (entry) {
                  final percentage = totalExpense == 0
                      ? 0.0
                      : entry.value / totalExpense;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                formatRupiah(entry.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(percentage * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            Card(
              child: ListTile(
                leading: const Icon(Icons.insights),
                title: const Text(
                  'Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  biggestCategory == '-'
                      ? 'Belum ada data pengeluaran.'
                      : 'Kategori pengeluaran terbesar adalah $biggestCategory sebesar ${formatRupiah(biggestAmount)}.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BUDGET
// ============================================================

class BudgetPage extends StatelessWidget {
  final List<TransactionModel> transactions;
  final double monthlyBudget;
  final Function(double) onBudgetChanged;

  const BudgetPage({
    super.key,
    required this.transactions,
    required this.monthlyBudget,
    required this.onBudgetChanged,
  });

  double get currentExpense {
    final now = DateTime.now();

    return transactions
        .where(
          (item) =>
      item.type == 'Pengeluaran' &&
          item.date.year == now.year &&
          item.date.month == now.month,
    )
        .fold(0, (sum, item) => sum + item.amount);
  }

  void _showBudgetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: monthlyBudget > 0
          ? monthlyBudget.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Atur Budget Bulanan'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.replaceAll('.', ''),
                );

                if (value == null || value <= 0) {
                  return;
                }

                controller.dispose();
                Navigator.pop(dialogContext);
                onBudgetChanged(value);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentage = monthlyBudget == 0
        ? 0.0
        : currentExpense / monthlyBudget;

    final isOverBudget =
        monthlyBudget > 0 && currentExpense > monthlyBudget;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget Bulanan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      monthlyBudget == 0
                          ? 'Belum diatur'
                          : formatRupiah(monthlyBudget),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          _showBudgetDialog(context);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Atur Budget'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penggunaan Bulan Ini',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRupiah(currentExpense),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: percentage > 1 ? 1 : percentage,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      monthlyBudget == 0
                          ? 'Silakan atur budget terlebih dahulu.'
                          : '${(percentage * 100).toStringAsFixed(1)}% dari budget digunakan.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (isOverBudget)
              Card(
                child: const ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: Colors.red,
                  ),
                  title: Text(
                    'Peringatan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Pengeluaran bulan ini telah melampaui budget.',
                  ),
                ),
              )
            else if (monthlyBudget > 0)
              Card(
                child: const ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  title: Text(
                    'Budget masih aman',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Pengeluaran bulan ini masih dalam batas budget.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FORMAT RUPIAH
// ============================================================

String formatRupiah(double value) {
  final number = value.round().toString();

  String result = '';
  int count = 0;

  for (int i = number.length - 1; i >= 0; i--) {
    result = number[i] + result;
    count++;

    if (count == 3 && i != 0) {
      result = '.$result';
      count = 0;
    }
  }

  return 'Rp $result';
}

// ============================================================
// FORMAT TANGGAL
// ============================================================

String formatDate(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}