# EcoKuha Project Structure Generator
# This script creates all remaining files for the EcoKuha Flutter project

$projectRoot = "c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha"

# Function to create a file if it doesn't exist
function New-ProjectFile {
    param(
        [string]$FilePath
    )
    
    $fullPath = Join-Path $projectRoot $FilePath
    
    if (!(Test-Path $fullPath)) {
        $directory = Split-Path $fullPath -Parent
        if (!(Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        New-Item -ItemType File -Path $fullPath -Force | Out-Null
        Write-Host "Created: $FilePath" -ForegroundColor Green
    } else {
        Write-Host "Exists: $FilePath" -ForegroundColor Yellow
    }
}

Write-Host "=== EcoKuha Project Structure Generator ===" -ForegroundColor Cyan
Write-Host "Creating remaining files..." -ForegroundColor White
Write-Host ""

# Shared Widgets - Forms
New-ProjectFile "lib\shared\widgets\forms\custom_dropdown.dart"
New-ProjectFile "lib\shared\widgets\forms\custom_checkbox.dart"
New-ProjectFile "lib\shared\widgets\forms\date_time_picker.dart"
New-ProjectFile "lib\shared\widgets\forms\image_picker_widget.dart"
New-ProjectFile "lib\shared\widgets\forms\form_section.dart"

# Shared Widgets - Lists
New-ProjectFile "lib\shared\widgets\lists\custom_list_tile.dart"
New-ProjectFile "lib\shared\widgets\lists\expandable_list.dart"
New-ProjectFile "lib\shared\widgets\lists\infinite_scroll_list.dart"

# Shared Models
New-ProjectFile "lib\shared\models\ui_state.dart"
New-ProjectFile "lib\shared\models\dropdown_item.dart"
New-ProjectFile "lib\shared\models\navigation_item.dart"
New-ProjectFile "lib\shared\models\pagination_model.dart"

# Shared Extensions
New-ProjectFile "lib\shared\extensions\context_extensions.dart"
New-ProjectFile "lib\shared\extensions\string_extensions.dart"
New-ProjectFile "lib\shared\extensions\date_extensions.dart"
New-ProjectFile "lib\shared\extensions\number_extensions.dart"

# Authentication Feature - Data Models
New-ProjectFile "lib\features\authentication\data\models\login_request_model.dart"
New-ProjectFile "lib\features\authentication\data\models\register_request_model.dart"
New-ProjectFile "lib\features\authentication\data\models\auth_response_model.dart"

# Authentication Feature - Domain
New-ProjectFile "lib\features\authentication\domain\repositories\auth_repository.dart"
New-ProjectFile "lib\features\authentication\domain\usecases\login_usecase.dart"
New-ProjectFile "lib\features\authentication\domain\usecases\register_usecase.dart"
New-ProjectFile "lib\features\authentication\domain\usecases\logout_usecase.dart"
New-ProjectFile "lib\features\authentication\domain\usecases\get_current_user_usecase.dart"

# Authentication Feature - Presentation BLoC
New-ProjectFile "lib\features\authentication\presentation\bloc\login\login_bloc.dart"
New-ProjectFile "lib\features\authentication\presentation\bloc\login\login_event.dart"
New-ProjectFile "lib\features\authentication\presentation\bloc\login\login_state.dart"
New-ProjectFile "lib\features\authentication\presentation\bloc\register\register_bloc.dart"
New-ProjectFile "lib\features\authentication\presentation\bloc\register\register_event.dart"
New-ProjectFile "lib\features\authentication\presentation\bloc\register\register_state.dart"

# Authentication Feature - Presentation Screens
New-ProjectFile "lib\features\authentication\presentation\screens\register_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\role_selection_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\household_registration_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\junkshop_registration\junkshop_step1_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\junkshop_registration\junkshop_step2_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\junkshop_registration\junkshop_step3_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\junkshop_registration\junkshop_step4_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\junkshop_registration\junkshop_pending_screen.dart"

# Create collector registration directories first
New-Item -ItemType Directory -Path "$projectRoot\lib\features\authentication\presentation\screens\registration\collector_registration" -Force | Out-Null

New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_step1_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_step2_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_step3_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_step4_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_step5_screen.dart"
New-ProjectFile "lib\features\authentication\presentation\screens\registration\collector_registration\collector_pending_screen.dart"

# Authentication Feature - Presentation Widgets
New-ProjectFile "lib\features\authentication\presentation\widgets\role_selection_card.dart"
New-ProjectFile "lib\features\authentication\presentation\widgets\progress_stepper.dart"
New-ProjectFile "lib\features\authentication\presentation\widgets\document_upload_widget.dart"

# Household Feature - Data
New-ProjectFile "lib\features\household\data\datasources\household_remote_datasource.dart"
New-ProjectFile "lib\features\household\data\repositories\household_repository_impl.dart"
New-ProjectFile "lib\features\household\data\models\waste_listing_model.dart"
New-ProjectFile "lib\features\household\data\models\waste_item_model.dart"
New-ProjectFile "lib\features\household\data\models\junkshop_model.dart"

# Household Feature - Domain
New-ProjectFile "lib\features\household\domain\entities\waste_listing_entity.dart"
New-ProjectFile "lib\features\household\domain\entities\household_stats_entity.dart"
New-ProjectFile "lib\features\household\domain\repositories\household_repository.dart"
New-ProjectFile "lib\features\household\domain\usecases\create_waste_listing_usecase.dart"
New-ProjectFile "lib\features\household\domain\usecases\get_junkshops_usecase.dart"
New-ProjectFile "lib\features\household\domain\usecases\get_collection_history_usecase.dart"

# Household Feature - Presentation BLoC
New-ProjectFile "lib\features\household\presentation\bloc\home\home_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\home\home_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\home\home_state.dart"
New-ProjectFile "lib\features\household\presentation\bloc\post_waste\post_waste_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\post_waste\post_waste_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\post_waste\post_waste_state.dart"
New-ProjectFile "lib\features\household\presentation\bloc\track\track_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\track\track_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\track\track_state.dart"
New-ProjectFile "lib\features\household\presentation\bloc\history\history_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\history\history_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\history\history_state.dart"
New-ProjectFile "lib\features\household\presentation\bloc\profile\profile_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\profile\profile_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\profile\profile_state.dart"
New-ProjectFile "lib\features\household\presentation\bloc\ai_scanner\ai_scanner_bloc.dart"
New-ProjectFile "lib\features\household\presentation\bloc\ai_scanner\ai_scanner_event.dart"
New-ProjectFile "lib\features\household\presentation\bloc\ai_scanner\ai_scanner_state.dart"

# Household Feature - Presentation Screens
New-ProjectFile "lib\features\household\presentation\screens\home_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\post_waste\post_waste_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\post_waste\ai_scanner_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\post_waste\schedule_pickup_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\post_waste\confirmation_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\track\track_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\track\track_details_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\track\collector_profile_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\history_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\profile\profile_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\profile\account_settings_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\profile\notification_settings_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\profile\help_support_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\junkshops\all_junkshops_screen.dart"
New-ProjectFile "lib\features\household\presentation\screens\junkshops\junkshop_profile_screen.dart"

# Household Feature - Presentation Widgets
New-ProjectFile "lib\features\household\presentation\widgets\stats_card.dart"
New-ProjectFile "lib\features\household\presentation\widgets\quick_action_item.dart"
New-ProjectFile "lib\features\household\presentation\widgets\activity_card.dart"
New-ProjectFile "lib\features\household\presentation\widgets\waste_item_card.dart"
New-ProjectFile "lib\features\household\presentation\widgets\ai_detection_result.dart"
New-ProjectFile "lib\features\household\presentation\widgets\junkshop_card.dart"
New-ProjectFile "lib\features\household\presentation\widgets\collection_status_card.dart"
New-ProjectFile "lib\features\household\presentation\widgets\achievement_badge.dart"
New-ProjectFile "lib\features\household\presentation\widgets\impact_stats_widget.dart"

Write-Host ""
Write-Host "=== Household Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Junkshop Feature..." -ForegroundColor Cyan

# Junkshop Feature - Data
New-ProjectFile "lib\features\junkshop\data\datasources\junkshop_remote_datasource.dart"
New-ProjectFile "lib\features\junkshop\data\repositories\junkshop_repository_impl.dart"
New-ProjectFile "lib\features\junkshop\data\models\pickup_model.dart"
New-ProjectFile "lib\features\junkshop\data\models\collector_model.dart"
New-ProjectFile "lib\features\junkshop\data\models\inventory_model.dart"
New-ProjectFile "lib\features\junkshop\data\models\analytics_model.dart"

# Junkshop Feature - Domain
New-ProjectFile "lib\features\junkshop\domain\entities\pickup_entity.dart"
New-ProjectFile "lib\features\junkshop\domain\entities\junkshop_stats_entity.dart"
New-ProjectFile "lib\features\junkshop\domain\entities\business_analytics_entity.dart"
New-ProjectFile "lib\features\junkshop\domain\repositories\junkshop_repository.dart"
New-ProjectFile "lib\features\junkshop\domain\usecases\get_pickups_usecase.dart"
New-ProjectFile "lib\features\junkshop\domain\usecases\assign_collector_usecase.dart"
New-ProjectFile "lib\features\junkshop\domain\usecases\manage_inventory_usecase.dart"

# Junkshop Feature - Presentation BLoC
New-ProjectFile "lib\features\junkshop\presentation\bloc\dashboard\dashboard_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\dashboard\dashboard_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\dashboard\dashboard_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\pickups\pickups_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\pickups\pickups_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\pickups\pickups_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\collectors\collectors_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\collectors\collectors_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\collectors\collectors_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\inventory\inventory_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\inventory\inventory_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\inventory\inventory_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\profile\profile_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\profile\profile_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\profile\profile_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\cashier\cashier_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\cashier\cashier_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\cashier\cashier_state.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\analytics\analytics_bloc.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\analytics\analytics_event.dart"
New-ProjectFile "lib\features\junkshop\presentation\bloc\analytics\analytics_state.dart"

# Junkshop Feature - Presentation Screens
New-ProjectFile "lib\features\junkshop\presentation\screens\dashboard_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\pickups\pickups_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\pickups\pickup_details_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\collectors\collectors_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\collectors\collector_details_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\collectors\worker_applications_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\inventory\inventory_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\profile\profile_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\profile\account_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\profile\price_management_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\profile\business_reports_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\profile\notifications_screen.dart"
New-ProjectFile "lib\features\junkshop\presentation\screens\history_screen.dart"

# Junkshop Feature - Presentation Widgets
New-ProjectFile "lib\features\junkshop\presentation\widgets\dashboard_stat_card.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\quick_action_grid.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\pickup_card.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\collector_card.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\inventory_card.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\price_list_item.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\application_card.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\analytics_chart.dart"
New-ProjectFile "lib\features\junkshop\presentation\widgets\cashier_modal.dart"

Write-Host ""
Write-Host "=== Junkshop Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Collector Feature..." -ForegroundColor Cyan

# Collector Feature - Data
New-ProjectFile "lib\features\collector\data\models\collection_task_model.dart"
New-ProjectFile "lib\features\collector\data\models\route_model.dart"

# Collector Feature - Domain
New-ProjectFile "lib\features\collector\domain\entities\collection_task_entity.dart"
New-ProjectFile "lib\features\collector\domain\entities\collector_stats_entity.dart"
New-ProjectFile "lib\features\collector\domain\entities\route_entity.dart"
New-ProjectFile "lib\features\collector\domain\repositories\collector_repository.dart"
New-ProjectFile "lib\features\collector\domain\usecases\get_assignments_usecase.dart"
New-ProjectFile "lib\features\collector\domain\usecases\update_status_usecase.dart"
New-ProjectFile "lib\features\collector\domain\usecases\complete_collection_usecase.dart"

# Collector Feature - Presentation BLoC
New-ProjectFile "lib\features\collector\presentation\bloc\home\collector_home_bloc.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\home\collector_home_event.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\home\collector_home_state.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\task\task_bloc.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\task\task_event.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\task\task_state.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\collections\collections_bloc.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\collections\collections_event.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\collections\collections_state.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\profile\collector_profile_bloc.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\profile\collector_profile_event.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\profile\collector_profile_state.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\availability\availability_bloc.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\availability\availability_event.dart"
New-ProjectFile "lib\features\collector\presentation\bloc\availability\availability_state.dart"

# Collector Feature - Presentation Screens
New-ProjectFile "lib\features\collector\presentation\screens\home_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\task\task_details_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\collections_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\profile\profile_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\profile\account_settings_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\profile\feedback_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\profile\notifications_screen.dart"
New-ProjectFile "lib\features\collector\presentation\screens\transaction_detail_screen.dart"

# Collector Feature - Presentation Widgets
New-ProjectFile "lib\features\collector\presentation\widgets\collection_card.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\availability_toggle.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\workflow_state_widget.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\household_info_card.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\photo_verification_widget.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\receipt_form_widget.dart"
New-ProjectFile "lib\features\collector\presentation\widgets\performance_stats.dart"

Write-Host ""
Write-Host "=== Collector Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Messaging Feature..." -ForegroundColor Cyan

# Messaging Feature - Data
New-ProjectFile "lib\features\messaging\data\datasources\chat_remote_datasource.dart"
New-ProjectFile "lib\features\messaging\data\datasources\chat_local_datasource.dart"
New-ProjectFile "lib\features\messaging\data\repositories\chat_repository_impl.dart"
New-ProjectFile "lib\features\messaging\data\models\chat_model.dart"
New-ProjectFile "lib\features\messaging\data\models\message_model.dart"
New-ProjectFile "lib\features\messaging\data\models\message_template_model.dart"

# Messaging Feature - Domain
New-ProjectFile "lib\features\messaging\domain\entities\chat_thread_entity.dart"
New-ProjectFile "lib\features\messaging\domain\entities\message_entity.dart"
New-ProjectFile "lib\features\messaging\domain\repositories\chat_repository.dart"
New-ProjectFile "lib\features\messaging\domain\usecases\send_message_usecase.dart"
New-ProjectFile "lib\features\messaging\domain\usecases\get_chats_usecase.dart"
New-ProjectFile "lib\features\messaging\domain\usecases\get_ai_suggestions_usecase.dart"

# Messaging Feature - Presentation BLoC
New-ProjectFile "lib\features\messaging\presentation\bloc\chat_list\chat_list_bloc.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\chat_list\chat_list_event.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\chat_list\chat_list_state.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\conversation\conversation_bloc.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\conversation\conversation_event.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\conversation\conversation_state.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\ai_assistant\ai_assistant_bloc.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\ai_assistant\ai_assistant_event.dart"
New-ProjectFile "lib\features\messaging\presentation\bloc\ai_assistant\ai_assistant_state.dart"

# Messaging Feature - Presentation Screens
New-ProjectFile "lib\features\messaging\presentation\screens\chat_list_screen.dart"
New-ProjectFile "lib\features\messaging\presentation\screens\conversation_screen.dart"
New-ProjectFile "lib\features\messaging\presentation\screens\new_chat_screen.dart"

# Messaging Feature - Presentation Widgets
New-ProjectFile "lib\features\messaging\presentation\widgets\chat_list_item.dart"
New-ProjectFile "lib\features\messaging\presentation\widgets\message_bubble.dart"
New-ProjectFile "lib\features\messaging\presentation\widgets\chat_input_widget.dart"
New-ProjectFile "lib\features\messaging\presentation\widgets\suggestion_chips.dart"
New-ProjectFile "lib\features\messaging\presentation\widgets\ai_assistant_modal.dart"
New-ProjectFile "lib\features\messaging\presentation\widgets\message_template_widget.dart"

Write-Host ""
Write-Host "=== Messaging Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with AI Feature..." -ForegroundColor Cyan

# AI Feature - Data
New-ProjectFile "lib\features\ai\data\datasources\ai_remote_datasource.dart"
New-ProjectFile "lib\features\ai\data\datasources\ai_local_datasource.dart"
New-ProjectFile "lib\features\ai\data\repositories\ai_repository_impl.dart"
New-ProjectFile "lib\features\ai\data\models\detection_result_model.dart"
New-ProjectFile "lib\features\ai\data\models\ai_response_model.dart"

# AI Feature - Domain
New-ProjectFile "lib\features\ai\domain\entities\detection_result_entity.dart"
New-ProjectFile "lib\features\ai\domain\entities\ai_response_entity.dart"
New-ProjectFile "lib\features\ai\domain\repositories\ai_repository.dart"
New-ProjectFile "lib\features\ai\domain\usecases\detect_waste_usecase.dart"
New-ProjectFile "lib\features\ai\domain\usecases\get_sorting_tips_usecase.dart"
New-ProjectFile "lib\features\ai\domain\usecases\generate_smart_reply_usecase.dart"

# AI Feature - Presentation BLoC
New-ProjectFile "lib\features\ai\presentation\bloc\waste_detection\waste_detection_bloc.dart"
New-ProjectFile "lib\features\ai\presentation\bloc\waste_detection\waste_detection_event.dart"
New-ProjectFile "lib\features\ai\presentation\bloc\waste_detection\waste_detection_state.dart"
New-ProjectFile "lib\features\ai\presentation\bloc\ai_assistant\ai_chat_bloc.dart"
New-ProjectFile "lib\features\ai\presentation\bloc\ai_assistant\ai_chat_event.dart"
New-ProjectFile "lib\features\ai\presentation\bloc\ai_assistant\ai_chat_state.dart"

# AI Feature - Presentation Screens
New-ProjectFile "lib\features\ai\presentation\screens\ai_scanner_screen.dart"
New-ProjectFile "lib\features\ai\presentation\screens\ai_assistant_screen.dart"

# AI Feature - Presentation Widgets
New-ProjectFile "lib\features\ai\presentation\widgets\camera_preview_widget.dart"
New-ProjectFile "lib\features\ai\presentation\widgets\detection_overlay_widget.dart"
New-ProjectFile "lib\features\ai\presentation\widgets\detection_results_widget.dart"
New-ProjectFile "lib\features\ai\presentation\widgets\ai_chat_widget.dart"

Write-Host ""
Write-Host "=== AI Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Maps Feature..." -ForegroundColor Cyan

# Maps Feature - Data
New-ProjectFile "lib\features\maps\data\datasources\location_remote_datasource.dart"
New-ProjectFile "lib\features\maps\data\repositories\location_repository_impl.dart"
New-ProjectFile "lib\features\maps\data\models\location_model.dart"

# Maps Feature - Domain
New-ProjectFile "lib\features\maps\domain\entities\map_location_entity.dart"
New-ProjectFile "lib\features\maps\domain\repositories\location_repository.dart"
New-ProjectFile "lib\features\maps\domain\usecases\get_current_location_usecase.dart"
New-ProjectFile "lib\features\maps\domain\usecases\track_location_usecase.dart"

# Maps Feature - Presentation BLoC
New-ProjectFile "lib\features\maps\presentation\bloc\maps\maps_bloc.dart"
New-ProjectFile "lib\features\maps\presentation\bloc\maps\maps_event.dart"
New-ProjectFile "lib\features\maps\presentation\bloc\maps\maps_state.dart"

# Maps Feature - Presentation Widgets
New-ProjectFile "lib\features\maps\presentation\widgets\custom_map_widget.dart"
New-ProjectFile "lib\features\maps\presentation\widgets\location_marker_widget.dart"
New-ProjectFile "lib\features\maps\presentation\widgets\route_overlay_widget.dart"

Write-Host ""
Write-Host "=== Maps Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Notifications Feature..." -ForegroundColor Cyan

# Notifications Feature - Data
New-ProjectFile "lib\features\notifications\data\datasources\notification_remote_datasource.dart"
New-ProjectFile "lib\features\notifications\data\repositories\notification_repository_impl.dart"
New-ProjectFile "lib\features\notifications\data\models\notification_model.dart"

# Notifications Feature - Domain
New-ProjectFile "lib\features\notifications\domain\entities\notification_entity.dart"
New-ProjectFile "lib\features\notifications\domain\repositories\notification_repository.dart"
New-ProjectFile "lib\features\notifications\domain\usecases\get_notifications_usecase.dart"
New-ProjectFile "lib\features\notifications\domain\usecases\mark_as_read_usecase.dart"

# Notifications Feature - Presentation BLoC
New-ProjectFile "lib\features\notifications\presentation\bloc\notifications\notifications_bloc.dart"
New-ProjectFile "lib\features\notifications\presentation\bloc\notifications\notifications_event.dart"
New-ProjectFile "lib\features\notifications\presentation\bloc\notifications\notifications_state.dart"

# Notifications Feature - Presentation Screens
New-ProjectFile "lib\features\notifications\presentation\screens\notifications_screen.dart"

# Notifications Feature - Presentation Widgets
New-ProjectFile "lib\features\notifications\presentation\widgets\notification_item.dart"
New-ProjectFile "lib\features\notifications\presentation\widgets\notification_settings_widget.dart"

Write-Host ""
Write-Host "=== Notifications Feature Complete ===" -ForegroundColor Green
Write-Host "Continuing with Localization..." -ForegroundColor Cyan

# Localization
New-ProjectFile "lib\l10n\app_en.json"
New-ProjectFile "lib\l10n\app_fil.json"
New-ProjectFile "lib\l10n\app_localizations.dart"

Write-Host ""
Write-Host "=== Localization Complete ===" -ForegroundColor Green
Write-Host "Continuing with Test Files..." -ForegroundColor Cyan

# Test Helpers
New-ProjectFile "test\helpers\test_helper.dart"
New-ProjectFile "test\helpers\mock_data.dart"
New-ProjectFile "test\helpers\pump_app.dart"

# Test Mocks
New-ProjectFile "test\mocks\mock_repositories.dart"
New-ProjectFile "test\mocks\mock_services.dart"
New-ProjectFile "test\mocks\mock_datasources.dart"
New-ProjectFile "test\mocks\mock_blocs.dart"

# Unit Tests - Core
New-ProjectFile "test\unit\core\utils\validators_test.dart"
New-ProjectFile "test\unit\core\utils\formatters_test.dart"
New-ProjectFile "test\unit\core\utils\date_utils_test.dart"
New-ProjectFile "test\unit\core\services\storage_service_test.dart"
New-ProjectFile "test\unit\core\services\location_service_test.dart"
New-ProjectFile "test\unit\core\services\ai_service_test.dart"

# Unit Tests - Authentication
New-ProjectFile "test\unit\features\authentication\domain\usecases\login_usecase_test.dart"
New-ProjectFile "test\unit\features\authentication\domain\usecases\register_usecase_test.dart"
New-ProjectFile "test\unit\features\authentication\domain\usecases\logout_usecase_test.dart"
New-ProjectFile "test\unit\features\authentication\data\repositories\auth_repository_impl_test.dart"
New-ProjectFile "test\unit\features\authentication\data\datasources\auth_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\authentication\data\datasources\auth_local_datasource_test.dart"
New-ProjectFile "test\unit\features\authentication\presentation\bloc\login\login_bloc_test.dart"

# Unit Tests - Household
New-ProjectFile "test\unit\features\household\domain\usecases\create_waste_listing_usecase_test.dart"
New-ProjectFile "test\unit\features\household\domain\usecases\get_junkshops_usecase_test.dart"
New-ProjectFile "test\unit\features\household\data\repositories\household_repository_impl_test.dart"
New-ProjectFile "test\unit\features\household\data\datasources\household_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\household\presentation\bloc\home\home_bloc_test.dart"
New-ProjectFile "test\unit\features\household\presentation\bloc\post_waste\post_waste_bloc_test.dart"
New-ProjectFile "test\unit\features\household\presentation\bloc\ai_scanner\ai_scanner_bloc_test.dart"

# Unit Tests - Junkshop
New-ProjectFile "test\unit\features\junkshop\domain\usecases\get_pickups_usecase_test.dart"
New-ProjectFile "test\unit\features\junkshop\domain\usecases\assign_collector_usecase_test.dart"
New-ProjectFile "test\unit\features\junkshop\data\repositories\junkshop_repository_impl_test.dart"
New-ProjectFile "test\unit\features\junkshop\data\datasources\junkshop_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\junkshop\presentation\bloc\dashboard\dashboard_bloc_test.dart"
New-ProjectFile "test\unit\features\junkshop\presentation\bloc\pickups\pickups_bloc_test.dart"
New-ProjectFile "test\unit\features\junkshop\presentation\bloc\cashier\cashier_bloc_test.dart"

# Unit Tests - Collector
New-ProjectFile "test\unit\features\collector\domain\usecases\get_assignments_usecase_test.dart"
New-ProjectFile "test\unit\features\collector\domain\usecases\update_status_usecase_test.dart"
New-ProjectFile "test\unit\features\collector\data\repositories\collector_repository_impl_test.dart"
New-ProjectFile "test\unit\features\collector\data\datasources\collector_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\collector\presentation\bloc\home\collector_home_bloc_test.dart"
New-ProjectFile "test\unit\features\collector\presentation\bloc\task\task_bloc_test.dart"
New-ProjectFile "test\unit\features\collector\presentation\bloc\availability\availability_bloc_test.dart"

# Unit Tests - Messaging
New-ProjectFile "test\unit\features\messaging\domain\usecases\send_message_usecase_test.dart"
New-ProjectFile "test\unit\features\messaging\domain\usecases\get_chats_usecase_test.dart"
New-ProjectFile "test\unit\features\messaging\data\repositories\chat_repository_impl_test.dart"
New-ProjectFile "test\unit\features\messaging\data\datasources\chat_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\messaging\data\datasources\chat_local_datasource_test.dart"
New-ProjectFile "test\unit\features\messaging\presentation\bloc\chat_list\chat_list_bloc_test.dart"
New-ProjectFile "test\unit\features\messaging\presentation\bloc\conversation\conversation_bloc_test.dart"

# Unit Tests - AI
New-ProjectFile "test\unit\features\ai\domain\usecases\detect_waste_usecase_test.dart"
New-ProjectFile "test\unit\features\ai\domain\usecases\get_sorting_tips_usecase_test.dart"
New-ProjectFile "test\unit\features\ai\data\repositories\ai_repository_impl_test.dart"
New-ProjectFile "test\unit\features\ai\data\datasources\ai_remote_datasource_test.dart"
New-ProjectFile "test\unit\features\ai\data\datasources\ai_local_datasource_test.dart"
New-ProjectFile "test\unit\features\ai\presentation\bloc\waste_detection\waste_detection_bloc_test.dart"
New-ProjectFile "test\unit\features\ai\presentation\bloc\ai_assistant\ai_chat_bloc_test.dart"

Write-Host ""
Write-Host "=== Unit Tests Complete ===" -ForegroundColor Green
Write-Host "Continuing with Widget Tests..." -ForegroundColor Cyan

# Widget Tests - Shared
New-ProjectFile "test\widget\shared\widgets\common\custom_button_test.dart"
New-ProjectFile "test\widget\shared\widgets\common\custom_text_field_test.dart"
New-ProjectFile "test\widget\shared\widgets\common\loading_widget_test.dart"
New-ProjectFile "test\widget\shared\widgets\common\custom_card_test.dart"
New-ProjectFile "test\widget\shared\widgets\navigation\custom_bottom_nav_test.dart"
New-ProjectFile "test\widget\shared\widgets\navigation\nav_item_test.dart"
New-ProjectFile "test\widget\shared\widgets\forms\custom_dropdown_test.dart"
New-ProjectFile "test\widget\shared\widgets\forms\date_time_picker_test.dart"

# Widget Tests - Authentication
New-ProjectFile "test\widget\features\authentication\screens\login_screen_test.dart"
New-ProjectFile "test\widget\features\authentication\screens\register_screen_test.dart"
New-ProjectFile "test\widget\features\authentication\screens\role_selection_screen_test.dart"
New-ProjectFile "test\widget\features\authentication\widgets\role_selection_card_test.dart"
New-ProjectFile "test\widget\features\authentication\widgets\progress_stepper_test.dart"

# Widget Tests - Household
New-ProjectFile "test\widget\features\household\screens\home_screen_test.dart"
New-ProjectFile "test\widget\features\household\screens\post_waste_screen_test.dart"
New-ProjectFile "test\widget\features\household\screens\track_screen_test.dart"
New-ProjectFile "test\widget\features\household\screens\history_screen_test.dart"
New-ProjectFile "test\widget\features\household\widgets\stats_card_test.dart"
New-ProjectFile "test\widget\features\household\widgets\activity_card_test.dart"
New-ProjectFile "test\widget\features\household\widgets\waste_item_card_test.dart"
New-ProjectFile "test\widget\features\household\widgets\ai_detection_result_test.dart"

# Widget Tests - Junkshop
New-ProjectFile "test\widget\features\junkshop\screens\dashboard_screen_test.dart"
New-ProjectFile "test\widget\features\junkshop\screens\pickups_screen_test.dart"
New-ProjectFile "test\widget\features\junkshop\screens\collectors_screen_test.dart"
New-ProjectFile "test\widget\features\junkshop\screens\inventory_screen_test.dart"
New-ProjectFile "test\widget\features\junkshop\widgets\dashboard_stat_card_test.dart"
New-ProjectFile "test\widget\features\junkshop\widgets\pickup_card_test.dart"
New-ProjectFile "test\widget\features\junkshop\widgets\collector_card_test.dart"
New-ProjectFile "test\widget\features\junkshop\widgets\inventory_card_test.dart"

# Widget Tests - Collector
New-ProjectFile "test\widget\features\collector\screens\home_screen_test.dart"
New-ProjectFile "test\widget\features\collector\screens\task_details_screen_test.dart"
New-ProjectFile "test\widget\features\collector\screens\collections_screen_test.dart"
New-ProjectFile "test\widget\features\collector\widgets\collection_card_test.dart"
New-ProjectFile "test\widget\features\collector\widgets\availability_toggle_test.dart"
New-ProjectFile "test\widget\features\collector\widgets\workflow_state_widget_test.dart"
New-ProjectFile "test\widget\features\collector\widgets\performance_stats_test.dart"

# Widget Tests - Messaging
New-ProjectFile "test\widget\features\messaging\screens\chat_list_screen_test.dart"
New-ProjectFile "test\widget\features\messaging\screens\conversation_screen_test.dart"
New-ProjectFile "test\widget\features\messaging\screens\new_chat_screen_test.dart"
New-ProjectFile "test\widget\features\messaging\widgets\chat_list_item_test.dart"
New-ProjectFile "test\widget\features\messaging\widgets\message_bubble_test.dart"
New-ProjectFile "test\widget\features\messaging\widgets\chat_input_widget_test.dart"
New-ProjectFile "test\widget\features\messaging\widgets\suggestion_chips_test.dart"

# Widget Tests - AI
New-ProjectFile "test\widget\features\ai\screens\ai_scanner_screen_test.dart"
New-ProjectFile "test\widget\features\ai\screens\ai_assistant_screen_test.dart"
New-ProjectFile "test\widget\features\ai\widgets\camera_preview_widget_test.dart"
New-ProjectFile "test\widget\features\ai\widgets\detection_overlay_widget_test.dart"
New-ProjectFile "test\widget\features\ai\widgets\detection_results_widget_test.dart"

Write-Host ""
Write-Host "=== Widget Tests Complete ===" -ForegroundColor Green
Write-Host "Continuing with Integration Tests..." -ForegroundColor Cyan

# Integration Tests
New-ProjectFile "test\integration\app_test.dart"
New-ProjectFile "test\integration\authentication\login_flow_test.dart"
New-ProjectFile "test\integration\authentication\registration_flow_test.dart"
New-ProjectFile "test\integration\authentication\logout_flow_test.dart"
New-ProjectFile "test\integration\household\post_waste_flow_test.dart"
New-ProjectFile "test\integration\household\ai_scanning_flow_test.dart"
New-ProjectFile "test\integration\household\tracking_flow_test.dart"
New-ProjectFile "test\integration\household\messaging_flow_test.dart"
New-ProjectFile "test\integration\junkshop\pickup_management_flow_test.dart"
New-ProjectFile "test\integration\junkshop\collector_assignment_flow_test.dart"
New-ProjectFile "test\integration\junkshop\cashier_flow_test.dart"
New-ProjectFile "test\integration\junkshop\inventory_management_flow_test.dart"
New-ProjectFile "test\integration\collector\availability_flow_test.dart"
New-ProjectFile "test\integration\collector\collection_workflow_test.dart"
New-ProjectFile "test\integration\collector\photo_verification_flow_test.dart"
New-ProjectFile "test\integration\cross_feature\messaging_integration_test.dart"
New-ProjectFile "test\integration\cross_feature\real_time_tracking_test.dart"
New-ProjectFile "test\integration\cross_feature\notification_flow_test.dart"

Write-Host ""
Write-Host "=== Integration Tests Complete ===" -ForegroundColor Green
Write-Host "Continuing with Asset Files..." -ForegroundColor Cyan

# Asset files
New-ProjectFile "assets\config\app_config.json"
New-ProjectFile "assets\config\material_prices.json"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "🎉 EcoKuha Project Structure Complete! 🎉" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Total Files Created: 300+" -ForegroundColor Green
Write-Host "✅ Clean Architecture: Data/Domain/Presentation" -ForegroundColor Green  
Write-Host "✅ Features: Authentication, Household, Junkshop, Collector, Messaging, AI, Maps, Notifications" -ForegroundColor Green
Write-Host "✅ Testing: Unit, Widget, Integration tests" -ForegroundColor Green
Write-Host "✅ Shared Components: Widgets, Models, Extensions" -ForegroundColor Green
Write-Host "✅ Assets: Ready for images, fonts, config files" -ForegroundColor Green
Write-Host ""
Write-Host "Your EcoKuha project is now ready for development! 🚀" -ForegroundColor Cyan
Write-Host ""
