<?php
    $logFile = '../going.txt';
    if(file_exists($logFile)){
        $logContent = file_get_contents($logFile);
        echo nl2br($logContent);
    } else {
        echo '无法找到日志文件。';
    }
?>
