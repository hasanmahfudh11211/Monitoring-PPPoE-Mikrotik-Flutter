import 'dart:convert';
import 'package:http/http.dart' as http;

class GenieACSService {
  final String baseUrl;
  final String username;
  final String password;

  GenieACSService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Get basic auth credentials
  String get _basicAuth => base64Encode(utf8.encode('$username:$password'));

  /// Make authenticated HTTP request
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    final requestHeaders = {
      'Authorization': 'Basic $_basicAuth',
      'Content-Type': 'application/json',
      ...?headers,
    };

    try {
      print('[GenieACS] $method request to: $url');
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: requestHeaders);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('[GenieACS] Response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('[GenieACS] Error: $e');
      throw Exception('Request failed: $e');
    }
  }

  /// Test connection to GenieACS server
  Future<bool> testConnection() async {
    try {
      print('[GenieACS] Testing connection to: $baseUrl');
      final response = await _makeRequest('GET', 'devices', headers: {
        'Accept': 'application/json',
      });
      
      print('[GenieACS] Response status: ${response.statusCode}');
      print('[GenieACS] Response body: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('[GenieACS] Connection test failed: $e');
      return false;
    }
  }

  /// Get all devices with query parameters
  Future<List<Map<String, dynamic>>> getDevices({
    int limit = 100,
    int skip = 0,
    String query = '',
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (limit > 0) queryParams['limit'] = limit.toString();
      if (skip > 0) queryParams['skip'] = skip.toString();
      
      final uri = Uri.parse('$baseUrl/devices');
      final urlWithParams = uri.replace(queryParameters: queryParams);
      
      final response = await http.get(
        urlWithParams,
        headers: {
          'Authorization': 'Basic $_basicAuth',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> devices = json.decode(response.body);
        final filteredDevices = <Map<String, dynamic>>[];
        
        for (var device in devices) {
          final deviceMap = Map<String, dynamic>.from(device);
          // Filter by PPPoE IP if query provided
          if (query.isNotEmpty) {
            final pppoeIp = _extractPPPoEIP(deviceMap);
            if (pppoeIp.toLowerCase().contains(query.toLowerCase())) {
              filteredDevices.add(deviceMap);
            }
          } else {
            filteredDevices.add(deviceMap);
          }
        }
        
        return filteredDevices;
      } else {
        throw Exception('Failed to fetch devices: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting devices: $e');
    }
  }
  
  /// Extract PPPoE IP from device data
  String _extractPPPoEIP(Map<String, dynamic> device) {
    // Try VirtualParameters first (most common for Huawei devices)
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      // Try pppIP (could be nested with _value or direct string)
      final pppIPObj = virtualParams['pppIP'];
      if (pppIPObj != null) {
        if (pppIPObj is Map<String, dynamic>) {
          final pppIP = pppIPObj['_value'];
          if (pppIP != null) return pppIP.toString();
        } else {
          return pppIPObj.toString();
        }
      }
      
      // Try pppoeIP (alternative name)
      final pppoeIPObj = virtualParams['pppoeIP'];
      if (pppoeIPObj != null) {
        if (pppoeIPObj is Map<String, dynamic>) {
          final pppoeIP = pppoeIPObj['_value'];
          if (pppoeIP != null) return pppoeIP.toString();
        } else {
          return pppoeIPObj.toString();
        }
      }
    }
    
    // Fallback to nested WAN paths
    return DeviceInfoExtractor._getNestedValue(device, [
      'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
      'Device.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'Device.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
      'WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
    ]) ?? '-';
  }

  /// Get single device by ID
  Future<Map<String, dynamic>> getDevice(String deviceId) async {
    try {
      final response = await _makeRequest('GET', 'devices/$deviceId', headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch device: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting device: $e');
    }
  }

  /// Get device by serial number
  Future<Map<String, dynamic>?> getDeviceBySerial(String serial) async {
    try {
      final response = await _makeRequest(
        'GET',
        'devices',
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> devices = json.decode(response.body);
        for (var device in devices) {
          if (device['_id'] == serial || device['_deviceId']?['_SerialNumber'] == serial) {
            return Map<String, dynamic>.from(device);
          }
        }
        return null;
      } else {
        throw Exception('Failed to search devices: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching device: $e');
    }
  }

  /// Get device tasks
  Future<List<Map<String, dynamic>>> getDeviceTasks(String deviceId) async {
    try {
      final response = await _makeRequest('GET', 'devices/$deviceId/tasks', headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> tasks = json.decode(response.body);
        return tasks.map((task) => Map<String, dynamic>.from(task)).toList();
      } else {
        throw Exception('Failed to fetch tasks: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting tasks: $e');
    }
  }

  /// Get presets
  Future<List<Map<String, dynamic>>> getPresets() async {
    try {
      final response = await _makeRequest('GET', 'presets', headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> presets = json.decode(response.body);
        return presets.map((preset) => Map<String, dynamic>.from(preset)).toList();
      } else {
        throw Exception('Failed to fetch presets: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting presets: $e');
    }
  }

  /// Get configurations
  Future<List<Map<String, dynamic>>> getConfigurations() async {
    try {
      final response = await _makeRequest('GET', 'configurations', headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> configs = json.decode(response.body);
        return configs.map((config) => Map<String, dynamic>.from(config)).toList();
      } else {
        throw Exception('Failed to fetch configurations: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting configurations: $e');
    }
  }

  /// Add tag to device
  Future<bool> addTag(String deviceId, String tag) async {
    try {
      final response = await _makeRequest(
        'POST',
        'devices/$deviceId/tags/$tag',
        headers: {
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Remove tag from device
  Future<bool> removeTag(String deviceId, String tag) async {
    try {
      final response = await _makeRequest(
        'DELETE',
        'devices/$deviceId/tags/$tag',
        headers: {
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Execute task on device
  Future<bool> executeTask(String deviceId, Map<String, dynamic> task) async {
    try {
      final response = await _makeRequest(
        'POST',
        'devices/$deviceId/tasks',
        headers: {
          'Accept': 'application/json',
        },
        body: task,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Change router password (Super User password)
  Future<bool> changePassword(String deviceId, String newPassword) async {
    try {
      print('[GenieACS] Changing password for device: $deviceId');
      
      // Create task to set device parameter
      // Based on JSON structure, VirtualParameters.superPassword is the Super User password
      final task = {
        'name': 'setParameterValues',
        'parameterValues': [
          {
            'path': 'VirtualParameters.superPassword',
            'value': newPassword,
          }
        ],
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      print('[GenieACS] Task data: $task');
      final success = await executeTask(deviceId, task);
      print('[GenieACS] Password change result: $success');
      
      return success;
    } catch (e) {
      print('[GenieACS] Error changing password: $e');
      return false;
    }
  }

  /// Reboot device
  Future<bool> rebootDevice(String deviceId) async {
    try {
      final task = {
        'name': 'reboot',
        'timestamp': DateTime.now().toIso8601String(),
      };
      return await executeTask(deviceId, task);
    } catch (e) {
      return false;
    }
  }

  /// Factory reset device
  Future<bool> factoryResetDevice(String deviceId) async {
    try {
      final task = {
        'name': 'factoryReset',
        'timestamp': DateTime.now().toIso8601String(),
      };
      return await executeTask(deviceId, task);
    } catch (e) {
      return false;
    }
  }

  /// Download device parameters
  Future<bool> downloadParameters(String deviceId) async {
    try {
      final task = {
        'name': 'download',
        'timestamp': DateTime.now().toIso8601String(),
      };
      return await executeTask(deviceId, task);
    } catch (e) {
      return false;
    }
  }

  /// Refresh device connection
  Future<bool> refreshConnection(String deviceId) async {
    try {
      final task = {
        'name': 'refreshObject',
        'timestamp': DateTime.now().toIso8601String(),
      };
      return await executeTask(deviceId, task);
    } catch (e) {
      return false;
    }
  }
}

/// Helper function to extract readable device info
class DeviceInfoExtractor {
  static String getDeviceId(Map<String, dynamic> device) {
    return device['_id']?.toString() ?? 'Unknown';
  }

  static String getSerialNumber(Map<String, dynamic> device) {
    // Try multiple possible paths for serial number
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final serialObj = virtualParams['getSerialNumber'];
      if (serialObj != null) {
        if (serialObj is Map<String, dynamic>) {
          final serial = serialObj['_value'];
          if (serial != null && serial.toString().isNotEmpty) return serial.toString();
        } else if (serialObj.toString().isNotEmpty) {
          return serialObj.toString();
        }
      }
    }
    
    return _getNestedValue(device, ['InternetGatewayDevice.DeviceInfo.SerialNumber._value']) ??
        _getNestedValue(device, ['Device.DeviceInfo.SerialNumber._value']) ??
        _getNestedValue(device, ['_deviceId._SerialNumber']) ??
        _getNestedValue(device, ['_deviceId.SerialNumber']) ??
        _getNestedValue(device, ['DeviceInfo.SerialNumber._value']) ??
        '-';
  }

  static String getProductClass(Map<String, dynamic> device) {
    return _getNestedValue(device, ['InternetGatewayDevice.DeviceInfo.ProductClass._value']) ??
        _getNestedValue(device, ['Device.DeviceInfo.ProductClass._value']) ??
        _getNestedValue(device, ['_deviceId._ProductClass']) ??
        _getNestedValue(device, ['_deviceId.ProductClass']) ??
        '-';
  }

  static String getOUI(Map<String, dynamic> device) {
    return _getNestedValue(device, ['InternetGatewayDevice.DeviceInfo.ManufacturerOUI._value']) ??
        _getNestedValue(device, ['Device.DeviceInfo.ManufacturerOUI._value']) ??
        _getNestedValue(device, ['_deviceId._OUI']) ??
        _getNestedValue(device, ['_deviceId.OUI']) ??
        '-';
  }

  static String getManufacturer(Map<String, dynamic> device) {
    return _getNestedValue(device, ['InternetGatewayDevice.DeviceInfo.Manufacturer._value']) ??
        _getNestedValue(device, ['Device.DeviceInfo.Manufacturer._value']) ??
        _getNestedValue(device, ['_deviceId._Manufacturer']) ??
        _getNestedValue(device, ['_deviceId.Manufacturer']) ??
        '-';
  }

  static String getModel(Map<String, dynamic> device) {
    return _getNestedValue(device, ['InternetGatewayDevice.DeviceInfo.ModelName._value']) ??
        _getNestedValue(device, ['Device.DeviceInfo.ModelName._value']) ??
        _getNestedValue(device, ['_deviceId.ModelName']) ??
        '-';
  }

  /// Helper to get nested value safely
  static String? _getNestedValue(Map<String, dynamic> device, List<String> paths) {
    for (var path in paths) {
      final keys = path.split('.');
      dynamic value = device;
      
      try {
        for (var key in keys) {
          if (value is Map<String, dynamic>) {
            value = value[key];
            if (value == null) break;
          } else {
            value = null;
            break;
          }
        }
        if (value != null) {
          return value.toString();
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  static String getConnectionStatus(Map<String, dynamic> device) {
    if (device['_lastInform'] != null) {
      final lastInform = DateTime.tryParse(device['_lastInform']);
      if (lastInform != null) {
        final diff = DateTime.now().difference(lastInform);
        if (diff.inMinutes < 15) {
          return 'Online';
        } else if (diff.inHours < 24) {
          return 'Idle';
        } else {
          return 'Offline';
        }
      }
    }
    return 'Offline';
  }

  static String getLastInform(Map<String, dynamic> device) {
    if (device['_lastInform'] != null) {
      try {
        final date = DateTime.parse(device['_lastInform']);
        final now = DateTime.now();
        final diff = now.difference(date);

        if (diff.inDays > 0) {
          return '${diff.inDays} hari lalu';
        } else if (diff.inHours > 0) {
          return '${diff.inHours} jam lalu';
        } else if (diff.inMinutes > 0) {
          return '${diff.inMinutes} menit lalu';
        } else {
          return 'Baru saja';
        }
      } catch (e) {
        return 'Invalid date';
      }
    }
    return 'Never';
  }

  static List<String> getTags(Map<String, dynamic> device) {
    final tags = device['_tags'];
    if (tags is List) {
      return tags.map((tag) => tag.toString()).toList();
    }
    return [];
  }

  static String getPPPoEUsername(Map<String, dynamic> device) {
    // Try VirtualParameters first
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final pppoeUsernameObj = virtualParams['pppoeUsername'];
      if (pppoeUsernameObj != null) {
        if (pppoeUsernameObj is Map<String, dynamic>) {
          final pppoeUsername = pppoeUsernameObj['_value'];
          if (pppoeUsername != null) return pppoeUsername.toString();
        } else {
          return pppoeUsernameObj.toString();
        }
      }
    }
    return '-';
  }

  static String getRXPower(Map<String, dynamic> device) {
    // Try VirtualParameters first
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final rxPowerObj = virtualParams['RXPower'];
      if (rxPowerObj != null) {
        if (rxPowerObj is Map<String, dynamic>) {
          final rxPower = rxPowerObj['_value'];
          if (rxPower != null) return rxPower.toString();
        } else {
          return rxPowerObj.toString();
        }
      }
    }
    return '-';
  }

  static String getPPPoEIP(Map<String, dynamic> device) {
    // Try VirtualParameters first (most common)
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      // Try pppoeIP
      final pppoeIPObj = virtualParams['pppoeIP'];
      if (pppoeIPObj != null) {
        if (pppoeIPObj is Map<String, dynamic>) {
          final pppoeIP = pppoeIPObj['_value'];
          if (pppoeIP != null) return pppoeIP.toString();
        } else {
          return pppoeIPObj.toString();
        }
      }
      
      // Try pppIP (alternative)
      final pppIPObj = virtualParams['pppIP'];
      if (pppIPObj != null) {
        if (pppIPObj is Map<String, dynamic>) {
          final pppIP = pppIPObj['_value'];
          if (pppIP != null) return pppIP.toString();
        } else {
          return pppIPObj.toString();
        }
      }
    }
    
    // Fallback to WAN paths
    return _getNestedValue(device, [
      'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
      'Device.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'Device.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
      'WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.ExternalIPAddress._value',
      'WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress._value',
    ]) ?? '-';
  }

  static String getIPTR069(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final ipObj = virtualParams['IPTR069'];
      if (ipObj != null) {
        if (ipObj is Map<String, dynamic>) {
          final ip = ipObj['_value'];
          if (ip != null && ip.toString().isNotEmpty) return ip.toString();
        } else if (ipObj.toString().isNotEmpty) {
          return ipObj.toString();
        }
      }
    }
    return '-';
  }

  static String getPonMac(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final ponMacObj = virtualParams['PonMac'];
      if (ponMacObj != null) {
        if (ponMacObj is Map<String, dynamic>) {
          final ponMac = ponMacObj['_value'];
          if (ponMac != null && ponMac.toString().isNotEmpty) return ponMac.toString();
        } else if (ponMacObj.toString().isNotEmpty) {
          return ponMacObj.toString();
        }
      }
    }
    return '-';
  }

  static String getTemperature(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final tempObj = virtualParams['gettemp'];
      if (tempObj != null) {
        if (tempObj is Map<String, dynamic>) {
          final temp = tempObj['_value'];
          if (temp != null) return '${temp}°C';
        } else {
          return '${tempObj}°C';
        }
      }
    }
    return '-';
  }

  static String getDeviceUptime(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final uptimeObj = virtualParams['getdeviceuptime'];
      if (uptimeObj != null) {
        if (uptimeObj is Map<String, dynamic>) {
          final uptime = uptimeObj['_value'];
          if (uptime != null) return uptime.toString();
        } else {
          return uptimeObj.toString();
        }
      }
    }
    return '-';
  }

  static String getPPPoEUptime(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final uptimeObj = virtualParams['getpppuptime'];
      if (uptimeObj != null) {
        if (uptimeObj is Map<String, dynamic>) {
          final uptime = uptimeObj['_value'];
          if (uptime != null) return uptime.toString();
        } else {
          return uptimeObj.toString();
        }
      }
    }
    return '-';
  }

  static String getPONMode(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final ponModeObj = virtualParams['getponmode'];
      if (ponModeObj != null) {
        if (ponModeObj is Map<String, dynamic>) {
          final ponMode = ponModeObj['_value'];
          if (ponMode != null) return ponMode.toString();
        } else {
          return ponModeObj.toString();
        }
      }
    }
    return '-';
  }

  static String getPPPoEMac(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final pppoeMacObj = virtualParams['pppoeMac'];
      if (pppoeMacObj != null) {
        if (pppoeMacObj is Map<String, dynamic>) {
          final pppoeMac = pppoeMacObj['_value'];
          if (pppoeMac != null) return pppoeMac.toString();
        } else {
          return pppoeMacObj.toString();
        }
      }
    }
    return '-';
  }

  static int getActiveDevices(Map<String, dynamic> device) {
    final virtualParams = device['VirtualParameters'];
    if (virtualParams != null && virtualParams is Map<String, dynamic>) {
      final activeDevicesObj = virtualParams['activedevices'];
      if (activeDevicesObj != null) {
        if (activeDevicesObj is Map<String, dynamic>) {
          final activeDevices = activeDevicesObj['_value'];
          if (activeDevices != null) {
            if (activeDevices is int) return activeDevices;
            return int.tryParse(activeDevices.toString()) ?? 0;
          }
        } else {
          return int.tryParse(activeDevicesObj.toString()) ?? 0;
        }
      }
    }
    return 0;
  }

  static Map<String, dynamic> getParameters(Map<String, dynamic> device) {
    final params = <String, dynamic>{};
    device.forEach((key, value) {
      if (!key.startsWith('_')) {
        params[key] = value;
      }
    });
    return params;
  }

  static Map<String, String> getVirtualParameters(Map<String, dynamic> device) {
    final virtualParams = <String, String>{};
    final virtualParamsData = device['VirtualParameters'];
    
    if (virtualParamsData != null && virtualParamsData is Map<String, dynamic>) {
      virtualParamsData.forEach((key, value) {
        // Skip _object and _writable fields
        if (key.startsWith('_')) return;
        
        // Extract _value if it's a nested object
        if (value is Map<String, dynamic> && value['_value'] != null) {
          virtualParams[key] = value['_value'].toString();
        } else {
          virtualParams[key] = value.toString();
        }
      });
    }
    return virtualParams;
  }

  static String? getIPAddress(Map<String, dynamic> device) {
    return device['InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress']
        ?.toString() ??
        device['Device.IP.Interface.1.IPv4Address.1.IPAddress']?.toString();
  }

  static String? getFirmwareVersion(Map<String, dynamic> device) {
    // Try nested paths with _value
    return _getNestedValue(device, [
      'InternetGatewayDevice.DeviceInfo.SoftwareVersion._value',
      'Device.DeviceInfo.SoftwareVersion._value',
      'InternetGatewayDevice.DeviceInfo.SoftwareVersion',
      'Device.DeviceInfo.SoftwareVersion',
    ]);
  }

  static String? getHardwareVersion(Map<String, dynamic> device) {
    // Try nested paths with _value
    return _getNestedValue(device, [
      'InternetGatewayDevice.DeviceInfo.HardwareVersion._value',
      'Device.DeviceInfo.HardwareVersion._value',
      'InternetGatewayDevice.DeviceInfo.HardwareVersion',
      'Device.DeviceInfo.HardwareVersion',
    ]);
  }
  
  static String getSSID(Map<String, dynamic> device) {
    // Try nested paths for SSID
    return _getNestedValue(device, [
      'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID._value',
      'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID',
      'Device.LANDevice.1.WLANConfiguration.1.SSID._value',
      'Device.LANDevice.1.WLANConfiguration.1.SSID',
      'LANDevice.1.WLANConfiguration.1.SSID._value',
      'LANDevice.1.WLANConfiguration.1.SSID',
    ]) ?? '-';
  }
  
  static String getMACAddress(Map<String, dynamic> device) {
    // Try nested paths for MAC
    return _getNestedValue(device, [
      'InternetGatewayDevice.LANDevice.1.LANHostConfigManagement.MACAddress._value',
      'InternetGatewayDevice.LANDevice.1.LANHostConfigManagement.MACAddress',
      'Device.LANDevice.1.LANHostConfigManagement.MACAddress._value',
      'Device.LANDevice.1.LANHostConfigManagement.MACAddress',
      'LANDevice.1.LANHostConfigManagement.MACAddress._value',
      'LANDevice.1.LANHostConfigManagement.MACAddress',
    ]) ?? '-';
  }
  
  static String getRegisteredTime(Map<String, dynamic> device) {
    if (device['_registered'] != null) {
      try {
        final date = DateTime.parse(device['_registered']);
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      } catch (e) {
        return device['_registered'].toString();
      }
    }
    return '-';
  }
  
  static String getLastCommunication(Map<String, dynamic> device) {
    if (device['_lastInform'] != null) {
      try {
        final date = DateTime.parse(device['_lastInform']);
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      } catch (e) {
        return device['_lastInform'].toString();
      }
    }
    return '-';
  }
  
  static String getRXPowerWithStatus(Map<String, dynamic> device) {
    final rxPowerStr = getRXPower(device);
    if (rxPowerStr == '-') return '-';
    
    try {
      final rxPower = double.parse(rxPowerStr);
      if (rxPower >= -20) return '$rxPower dBm Bagus';
      if (rxPower >= -25) return '$rxPower dBm Lumayan';
      if (rxPower >= -30) return '$rxPower dBm Kritis';
      return '$rxPower dBm';
    } catch (e) {
      return '$rxPowerStr dBm';
    }
  }
  
  static String getTemperatureWithStatus(Map<String, dynamic> device) {
    final tempStr = getTemperature(device);
    if (tempStr == '-') return '-';
    
    try {
      final temp = tempStr.replaceAll('°C', '').trim();
      final tempVal = int.tryParse(temp);
      if (tempVal != null) {
        if (tempVal < 40) return '$tempVal°C Adem';
        if (tempVal < 55) return '$tempVal°C Anget';
        return '$tempVal°C Panas';
      }
      return tempStr;
    } catch (e) {
      return tempStr;
    }
  }
  
  static String getActiveWithStatus(Map<String, dynamic> device) {
    final activeCount = getActiveDevices(device);
    if (activeCount == 0) return '0 Empty';
    if (activeCount <= 5) return '$activeCount Normal';
    if (activeCount <= 10) return '$activeCount Medium';
    return '$activeCount Over';
  }
}

