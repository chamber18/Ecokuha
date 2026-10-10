$f = "lib\features\household\presentation\screens\material_scanning_screen.dart"
$c = [System.IO.File]::ReadAllText((Resolve-Path $f).Path, [System.Text.Encoding]::UTF8)
$NL = "`r`n"

# ===== 1. EST. VALUE — replace only the style block (no ${} vars) =====
$oldEst = "                    style: AppTextStyles.bodySmall.copyWith(" + $NL +
"                      color:" + $NL +
"                          _estimatedValueMin == 0.0 && _estimatedValueMax == 0.0" + $NL +
"                          ? Colors.grey[500]" + $NL +
"                          : Colors.grey[700]," + $NL +
"                    ),"

$newEst = "                    style: AppTextStyles.bodyMedium.copyWith(" + $NL +
"                      fontWeight: FontWeight.w600," + $NL +
"                      color:" + $NL +
"                          _estimatedValueMin == 0.0 && _estimatedValueMax == 0.0" + $NL +
"                          ? Colors.grey[400]" + $NL +
"                          : AppColors.primaryGreen," + $NL +
"                    ),"

if (-not $c.Contains($oldEst)) { Write-Host "ERROR: Est.Value style block not found"; exit 1 }
$c = $c.Replace($oldEst, $newEst)
Write-Host "1/4 Est.Value done"

# ===== 2. ACCEPTABLE RESULTS — header + spacing =====
$oldAccTop = "              if (_topResults.length > 1) ...[" + $NL +
"                const SizedBox(height: AppDimensions.spacing12)," + $NL +
"                Text(" + $NL +
"                  'Not right? Select the correct material:'," + $NL +
"                  style: AppTextStyles.caption.copyWith(" + $NL +
"                    color: Colors.grey[600]," + $NL +
"                  )," + $NL +
"                )," + $NL +
"                const SizedBox(height: 6)," + $NL +
"                SingleChildScrollView(" + $NL +
"                  scrollDirection: Axis.horizontal," + $NL +
"                  child: Row(" + $NL +
"                    children: _topResults.map((topResult) {" + $NL +
"                      final isSelected = topResult.label == result.label;" + $NL +
"                      return Padding(" + $NL +
"                        padding: const EdgeInsets.only(right: 8),"

$newAccTop = "              if (_topResults.length > 1) ...[" + $NL +
"                const SizedBox(height: AppDimensions.spacing16)," + $NL +
"                Text(" + $NL +
"                  'Not right? Select the correct material:'," + $NL +
"                  style: AppTextStyles.bodySmall.copyWith(" + $NL +
"                    color: Colors.grey[700]," + $NL +
"                    fontWeight: FontWeight.w600," + $NL +
"                  )," + $NL +
"                )," + $NL +
"                const SizedBox(height: 8)," + $NL +
"                SingleChildScrollView(" + $NL +
"                  scrollDirection: Axis.horizontal," + $NL +
"                  child: Row(" + $NL +
"                    children: _topResults.map((topResult) {" + $NL +
"                      final isSelected = topResult.label == result.label;" + $NL +
"                      return Padding(" + $NL +
"                        padding: const EdgeInsets.only(right: 10),"

if (-not $c.Contains($oldAccTop)) { Write-Host "ERROR: Acc top not found"; exit 1 }
$c = $c.Replace($oldAccTop, $newAccTop)
Write-Host "2/4 Acceptable header done"

# ===== 3. BOTH CHIP CONTAINERS — padding, radius, icon size, text style =====
# Both acceptable & unacceptable share identical chip markup — replace all
$oldChip = "                          child: Container(" + $NL +
"                            padding: const EdgeInsets.symmetric(" + $NL +
"                              horizontal: 12," + $NL +
"                              vertical: 6," + $NL +
"                            )," + $NL +
"                            decoration: BoxDecoration(" + $NL +
"                              color: isSelected" + $NL +
"                                  ? AppColors.primaryGreen" + $NL +
"                                  : Colors.grey[100]," + $NL +
"                              borderRadius: BorderRadius.circular(20)," + $NL +
"                              border: Border.all(" + $NL +
"                                color: isSelected" + $NL +
"                                    ? AppColors.primaryGreen" + $NL +
"                                    : Colors.grey[300]!," + $NL +
"                              )," + $NL +
"                            )," + $NL +
"                            child: Row(" + $NL +
"                              mainAxisSize: MainAxisSize.min," + $NL +
"                              children: [" + $NL +
"                                if (isSelected)" + $NL +
"                                  const Padding(" + $NL +
"                                    padding: EdgeInsets.only(right: 4)," + $NL +
"                                    child: Icon(" + $NL +
"                                      Icons.check," + $NL +
"                                      size: 14," + $NL +
"                                      color: Colors.white," + $NL +
"                                    )," + $NL +
"                                  )," + $NL +
"                                Text(" + $NL +
"                                  '" + '${topResult.label}  ${(topResult.confidence * 100).toStringAsFixed(0)}%' + "'," + $NL +
"                                  style: AppTextStyles.caption.copyWith(" + $NL +
"                                    color: isSelected" + $NL +
"                                        ? Colors.white" + $NL +
"                                        : Colors.black87," + $NL +
"                                    fontWeight: isSelected" + $NL +
"                                        ? FontWeight.w600" + $NL +
"                                        : FontWeight.normal," + $NL +
"                                  ),"

$newChip = "                          child: Container(" + $NL +
"                            padding: const EdgeInsets.symmetric(" + $NL +
"                              horizontal: 16," + $NL +
"                              vertical: 10," + $NL +
"                            )," + $NL +
"                            decoration: BoxDecoration(" + $NL +
"                              color: isSelected" + $NL +
"                                  ? AppColors.primaryGreen" + $NL +
"                                  : Colors.grey[100]," + $NL +
"                              borderRadius: BorderRadius.circular(24)," + $NL +
"                              border: Border.all(" + $NL +
"                                color: isSelected" + $NL +
"                                    ? AppColors.primaryGreen" + $NL +
"                                    : Colors.grey[300]!," + $NL +
"                                width: isSelected ? 2 : 1," + $NL +
"                              )," + $NL +
"                            )," + $NL +
"                            child: Row(" + $NL +
"                              mainAxisSize: MainAxisSize.min," + $NL +
"                              children: [" + $NL +
"                                if (isSelected)" + $NL +
"                                  const Padding(" + $NL +
"                                    padding: EdgeInsets.only(right: 6)," + $NL +
"                                    child: Icon(" + $NL +
"                                      Icons.check," + $NL +
"                                      size: 16," + $NL +
"                                      color: Colors.white," + $NL +
"                                    )," + $NL +
"                                  )," + $NL +
"                                Text(" + $NL +
"                                  '" + '${topResult.label}  ${(topResult.confidence * 100).toStringAsFixed(0)}%' + "'," + $NL +
"                                  style: AppTextStyles.bodySmall.copyWith(" + $NL +
"                                    color: isSelected" + $NL +
"                                        ? Colors.white" + $NL +
"                                        : Colors.black87," + $NL +
"                                    fontWeight: isSelected" + $NL +
"                                        ? FontWeight.w600" + $NL +
"                                        : FontWeight.normal," + $NL +
"                                  ),"

$count = ([regex]::Matches($c, [regex]::Escape($oldChip))).Count
if ($count -eq 0) { Write-Host "ERROR: chip Container block not found" ; exit 1 }
Write-Host "Found $count chip block(s)"
$c = $c.Replace($oldChip, $newChip)
Write-Host "3/4 Chip containers done"

# ===== 4. UNACCEPTABLE RESULTS — add header label + bigger spacing =====
$oldUnaccTop = "              if (topGuesses.isNotEmpty) ...[" + $NL +
"                const SizedBox(height: AppDimensions.spacing12)," + $NL +
"                SingleChildScrollView("

$newUnaccTop = "              if (topGuesses.isNotEmpty) ...[" + $NL +
"                const SizedBox(height: AppDimensions.spacing16)," + $NL +
"                Text(" + $NL +
"                  'Not right? Select the correct material:'," + $NL +
"                  style: AppTextStyles.bodySmall.copyWith(" + $NL +
"                    color: Colors.grey[700]," + $NL +
"                    fontWeight: FontWeight.w600," + $NL +
"                  )," + $NL +
"                )," + $NL +
"                const SizedBox(height: 8)," + $NL +
"                SingleChildScrollView("

if (-not $c.Contains($oldUnaccTop)) { Write-Host "ERROR: Unacc top not found"; exit 1 }
$c = $c.Replace($oldUnaccTop, $newUnaccTop)

# Fix chip gap for unacceptable (right: 8 -> right: 10)
$oldUnaccPad = "                    children: topGuesses.map((topResult) {" + $NL +
"                      final isSelected =" + $NL +
"                          _manuallySelectedMaterial?.label == topResult.label;" + $NL +
"                      return Padding(" + $NL +
"                        padding: const EdgeInsets.only(right: 8),"

$newUnaccPad = "                    children: topGuesses.map((topResult) {" + $NL +
"                      final isSelected =" + $NL +
"                          _manuallySelectedMaterial?.label == topResult.label;" + $NL +
"                      return Padding(" + $NL +
"                        padding: const EdgeInsets.only(right: 10),"

if (-not $c.Contains($oldUnaccPad)) { Write-Host "ERROR: Unacc padding not found"; exit 1 }
$c = $c.Replace($oldUnaccPad, $newUnaccPad)
Write-Host "4/4 Unacceptable done"

[System.IO.File]::WriteAllText((Resolve-Path $f).Path, $c, [System.Text.Encoding]::UTF8)
Write-Host "SAVED OK"
