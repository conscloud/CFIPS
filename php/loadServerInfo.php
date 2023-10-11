<?php
$load = sys_getloadavg();
$cpuCores = shell_exec("nproc");
$cpuUsage = shell_exec("top -b -n1 | grep 'Cpu(s)' | awk '{print $2 + $4}'");
$memoryData = explode(" ", trim(shell_exec("free -m | awk 'NR==2{printf \"%.2f%% %s %s\", $3*100/$2, $3, $2 }'")));

echo "<div>";
echo "服务器负载： " . round($load[0]/$cpuCores*100, $cpuCores) . "%  ". round($load[0], $cpuCores) ."/". round($load[1], $cpuCores) ."/". round($load[2], $cpuCores) ."<br>";
echo "CPU核心数： " . $cpuCores . "<br>";
echo "CPU使用率： " . $cpuUsage . "%<br>";
echo "内存使用率： " . $memoryData[0] . "  ". $memoryData[1] ."/". $memoryData[2] ." (MB)<br>";
echo "</div>";
?>
