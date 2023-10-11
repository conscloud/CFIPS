<!DOCTYPE html>
<html>
<head>
    <title>CloudFlareIPScan</title>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <style>
        #scanLog {
            height: 300px;
            overflow: auto;
            border: 1px solid black;
            padding: 10px;
        }
        #progressBar {
            width: 100%;
            background-color: #f3f3f3;
        }
        #progressBar div {
            height: 30px;
            background-color: #4CAF50;
            text-align: right;
            line-height: 30px;
            color: white;
        }
    </style>
    <script>
        $(document).ready(function(){
            loadStatus();
            loadLog();
            setInterval(loadStatus, 30000);
            setInterval(loadLog, 30000);
        });

        function loadStatus() {
            $.get('loadStatus.php', function(data) {
                var lines = data.split('<br>');
                $('#status').html(lines.slice(0, -2).join('<br>'));
                var progress = lines[lines.length - 2];
                progress = progress.replace('扫描进度：', '').replace('%', '');
                $('#progressBar div').css('width', progress + '%').text(progress + '%');
            });
        }

        function loadLog() {
            $("#scanLog").load('loadLog.php', function() {
                var elem = document.getElementById('scanLog');
                elem.scrollTop = elem.scrollHeight;
            });
        }
    </script>
</head>
<body>
    <h1>CloudFlareIPScan</h1>
    <div id="status"></div>
	<br>
    <div id="scanLog"></div>
	<div id="progressBar"><div></div></div>
</body>
</html>
