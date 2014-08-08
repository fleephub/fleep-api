<?php
if( $_POST["message"] && $_POST["url"] ) { 
	echo "Message: ". $_POST['message'];
	echo "<br/>";
	echo "URL: ". $_POST['url'];
	echo "<br/>";
	
	$data = array('message' => urlencode($_POST['message']));
	
	foreach($data as $key=>$value) { $fields_string .= $key.'='.$value.'&'; }
	rtrim($fields_string, '&');

	$ch = curl_init($_POST['url']);
	curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
	curl_setopt($ch, CURLOPT_POSTFIELDS, $fields_string);
	curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/x-www-form-urlencoded'));
	$result = curl_exec($ch);
	curl_close($ch);
} else {
	echo "Data missing";
}
exit();
?>