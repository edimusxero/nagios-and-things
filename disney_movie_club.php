#!/usr/bin/php7.2
<?php
    define('CONFIG_FILE', '/usr/local/etc/user.ini');

    // Parse config file so we can access the variables
    $params = parse_ini_file(CONFIG_FILE);

    define('USER_AGENT', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0');
    define('COOKIE_FILE', '/home/nagios/disney.cookie');
    define('MAIN_URL', 'https://disneymovieclub.go.com/webapp/wcs/stores/servlet/');
    define('USERNAME', $params['username']);
    define('PASSWORD', $params['password']);

    if(file_exists(COOKIE_FILE)){
        chmod(COOKIE_FILE,0777);
        unlink(COOKIE_FILE);
    }

    $login_values = array(
        'langId'            => '-1',
        'storeId'           => '10001',
        'login'             => 'Login',
        'cycleId'           => '',
        'offerId'           => '',
        'twoPack'           => '',
        'catalogId'         => '10051',
        'logonReturnMember' => '',
        'logonReLogonURL'   => 'DMCLoginView',
        'logonURL'          => 'DMCIndexView',
        'logonCreateURL'    => 'DMCLoginCreateMemberView',
        'logonId'           => USERNAME,
        'logonPassword'     => PASSWORD,
        'rememberMe'        => 'on',
    );

    $content = build_request('DMCLoginCmd',$login_values);

    $check_offer = get_offer_url($content);

    if($check_offer){
        parse_str(parse_url($check_offer, PHP_URL_QUERY), $array);
        $content = build_request('DMCFeaturedTitleDecisionView', $array);
        $featured = featured_title($content);
        $exit_message = "WARNING: Available Title: "  . $featured . PHP_EOL;
        $exit_code = 1;
        print $exit_message;
    }
    else {
        $exit_code = 0;
        $exit_message = 'OK: No Current Titles';
        print $exit_message;
    }

    $logout_values = array(
        'catalogId'     => '10051',
        'storeId'       => '10001',
        'langId'        => '-1',
        'rememberMe'    => 'false',
        'URL'           => 'DMCLoginView'
    );

    $content = build_request('DMCLogoffCmd', $logout_values);

    exit($exit_code);

    function build_request($cmd,$post){
        $curl = curl_init();

        $request = array(
            CURLOPT_URL             => MAIN_URL . '/' . $cmd,
            CURLOPT_POST            => true,
            CURLOPT_POSTFIELDS      => http_build_query($post),
            CURLOPT_SSL_VERIFYHOST  => false,
            CURLOPT_SSL_VERIFYPEER  => false,
            CURLOPT_COOKIEJAR       => COOKIE_FILE,
            CURLOPT_COOKIEFILE      => COOKIE_FILE,
            CURLOPT_USERAGENT       => USER_AGENT,
            CURLOPT_RETURNTRANSFER  => true,
            CURLOPT_FOLLOWLOCATION  => true,
            CURLINFO_HEADER_OUT     => true
        );

        curl_setopt_array($curl, $request);

        if(curl_errno($curl)){
            throw new Exception(curl_error($curl));
        }

        $content = curl_exec($curl);
        curl_close($curl);
        return($content);
    }

    function get_offer_url($html){
        $doc = new DOMDocument();
        libxml_use_internal_errors(true);

        $doc->loadHTML('<?xml encoding="UTF-8">' . $html);
        $doc->saveHTML();
        $nodes = $doc->getElementsByTagName('div');

        foreach($nodes as $class){
            $class_name = $class->getAttribute('class');
            if($class_name == 'FTIMAGE1'){
                $a_href = $class->getElementsByTagName('a');
                foreach($a_href as $a_href){
                    return $a_href->getAttribute('href');
                }
            }
        }
        return null;
    }

    function featured_title($html){
        $doc = new DOMDocument();
        libxml_use_internal_errors(true);

        $doc->loadHTML('<?xml encoding="UTF-8">' . $html);
        $doc->saveHTML();
        $nodes = $doc->getElementsByTagName('a');

        foreach($nodes as $href){
            $id_name = $href->getAttribute('id');
            if($id_name == 'ft_dmcTitle'){
                return trim($href->nodeValue);
            }
        }
    }
?>
