import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/services/material_analytics_service.dart';
import '../../bloc/material_analytics/material_analytics_bloc.dart';
import '../../bloc/material_analytics/material_analytics_event.dart';
import 'tabs/overview_tab.dart';
import 'tabs/materials_tab.dart';
import 'tabs/customers_tab.dart';

class AnalyticsScreen extends StatefulWidget {
  final int initialTabIndex;

  const AnalyticsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _selectedPeriod = 'Last 30 Days';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MaterialAnalyticsBloc(analyticsService: MaterialAnalyticsService())
            ..add(const LoadMaterialAnalytics()),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.junkshopPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Analytics',
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Materials'),
              Tab(text: 'Customers'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            OverviewTab(
              selectedPeriod: _selectedPeriod,
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
              onTabSwitch: (index) => _tabController.animateTo(index),
            ),
            const MaterialsTab(),
            CustomersTab(
              selectedPeriod: _selectedPeriod,
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
            ),
          ],
        ),
      ),
    );
  }
}
