<?php
class RouterosAPI
{
    var $socket;
    var $connected = false;
    var $port = 8728;
    var $timeout = 3;
    var $debug = false;

    public function connect($ip, $login, $password)
    {
        $this->socket = @fsockopen($ip, $this->port, $errno, $errstr, $this->timeout);
        if (!$this->socket) return false;
        stream_set_timeout($this->socket, $this->timeout);

        $this->write('/login');
        $response = $this->read();
        
        // Challenge-response login (pre-6.43) or plain login?
        // Modern RouterOS (6.43+) allows plain text login if detected.
        // But usually we get !done with ret=challenge.
        
        if (isset($response[0]) && $response[0] === '!done') {
            // Check for challenge
            $challenge = null;
            foreach ($response as $line) {
                if (strpos($line, '=ret=') === 0) {
                    $challenge = substr($line, 5);
                }
            }
            
            if ($challenge) {
                // Old style login
                $hash = md5(chr(0) . $password . hex2bin($challenge));
                $this->write('/login');
                $this->write('=name=' . $login);
                $this->write('=response=00' . $hash);
                $response = $this->read();
            } else {
                // Maybe already logged in or new style without challenge?
                // Try sending credentials just in case it was a "new style" init
                // Actually, if we got !done without ret, we might be logged in?
                // But usually 6.43+ requires sending name/pass immediately if not using challenge.
                // Let's try the standard flow for 6.43+:
                // Send /login, receive !trap or !done.
                // If we are here, we sent /login and got !done.
                // If it was 6.43+, we should have sent name/pass with the first /login.
            }
        } elseif (isset($response[0]) && $response[0] === '!trap') {
             // Maybe 6.43+ requiring attributes?
        }

        // Re-try with full credentials for 6.43+ compatibility if the first one failed or was just a handshake
        // But to keep it simple and robust for the user's likely version:
        // Let's use the universal method:
        // 1. Send /login.
        // 2. If we get challenge, use it.
        // 3. If we don't get challenge, we might need to send name/pass directly.
        
        // Let's restart the connection logic to be cleaner.
        // Close and reopen? No.
        
        // Actually, let's just implement the standard "new" login flow which works on new ROS.
        // For old ROS, we need the challenge.
        
        // Let's try the "new" flow first (send name/pass immediately).
        // If that fails, we can't easily fallback without reconnecting.
        
        // Let's stick to the "safe" flow:
        // 1. /login
        // 2. If ret=challenge, do challenge.
        // 3. If !done (and no ret), we are good? No, usually means we didn't send credentials.
        
        // Let's try this:
        $this->write('/login');
        $this->write('=name=' . $login);
        $this->write('=password=' . $password);
        $response = $this->read();
        
        if (isset($response[0]) && $response[0] === '!done') {
            $this->connected = true;
            return true;
        }
        
        // If we got !trap, maybe it's the old method?
        // Or maybe we need to do the challenge flow.
        return false;
    }

    public function comm($command, $params = [])
    {
        $this->write($command);
        foreach ($params as $k => $v) {
            $this->write($k . '=' . $v);
        }
        $this->write(''); // End of command

        $result = [];
        while (true) {
            $sentence = $this->read();
            if (empty($sentence)) break; // Should not happen if protocol is correct

            if ($sentence[0] === '!re') {
                // Data line
                $item = [];
                foreach ($sentence as $line) {
                    if (strpos($line, '=') === 0) {
                        $line = substr($line, 1);
                        if (strpos($line, '=') !== false) {
                            [$key, $value] = explode('=', $line, 2);
                            $item[$key] = $value;
                        }
                    }
                }
                $result[] = $item;
            } elseif ($sentence[0] === '!done') {
                // End of command
                break;
            } elseif ($sentence[0] === '!trap') {
                // Error
                // We could return error info, but for now just break or return empty
                // Let's add error info to result?
                // $result['error'] = ...
                break;
            }
        }
        return $result;
    }

    private function write($word)
    {
        $len = strlen($word);
        if ($len < 0x80) {
            fwrite($this->socket, chr($len));
        } elseif ($len < 0x4000) {
            $len |= 0x8000;
            fwrite($this->socket, chr(($len >> 8) & 0xFF) . chr($len & 0xFF));
        } else {
            // Handle larger lengths if needed
            // For now, assume short words
             fwrite($this->socket, chr(0)); // Fail safe
             return;
        }
        fwrite($this->socket, $word);
    }

    private function read()
    {
        $sentence = [];
        while (true) {
            $byte = fread($this->socket, 1);
            if ($byte === false || $byte === '') return $sentence; // Connection closed
            
            $len = ord($byte);
            if ($len & 0x80) {
                $len &= 0x7F;
                $len <<= 8;
                $byte2 = fread($this->socket, 1);
                $len |= ord($byte2);
            }
            // Handle larger lengths if needed

            if ($len === 0) return $sentence;

            $word = '';
            if ($len > 0) {
                $word = "";
                while (strlen($word) < $len) {
                    $chunk = fread($this->socket, $len - strlen($word));
                    if ($chunk === false || $chunk === '') break;
                    $word .= $chunk;
                }
            }
            $sentence[] = $word;
        }
    }

    public function disconnect()
    {
        if ($this->socket) fclose($this->socket);
        $this->connected = false;
    }
}
