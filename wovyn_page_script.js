angular.module('wovyn_page_script', [])
  .controller('MainCtrl', [
    '$scope', '$http',
    function ($scope, $http) {
      $scope.currentTemperature = -400.0;
      $scope.name = "no_name";
      $scope.phone = "12345678901";
      $scope.location = "location_unknown";
      $scope.temperatureThreshold = 75;
      $scope.temperatures = new Map();
      $scope.thresholdViolations = new Map();

      $scope.eci = "Uoc3txAdn1AhTAkPnMqbZz";

      $scope.updateProfile = function () {
        var bURL = 'http://localhost:8080/sky/event/' + $scope.eci + '/eid/sensor/profile_updated';
        var pURL = bURL + "?phone_number=" + $scope.phone + "&name=" + $scope.name;
        pURL = pURL + "&threshold=" + $scope.temperatureThreshold + "&location=" + $scope.location;
        return $http.post(pURL).success(function (data) {
          $scope.getAllTemps();
          $scope.getViolations();
          $scope.getCurrentTemp();
          $scope.getProfile();
        });
      };

      $scope.getAllTemps = function () {
        var gURL = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/temperature_store/temperatures';
        return $http.get(gURL).success(function (data) {
          $scope.temperatures = data;
        });
      };

      $scope.getCurrentTemp = function () {
        var gURL = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/temperature_store/current_temperature';
        return $http.get(gURL).success(function (data) {
          console.log(data);
          $scope.currentTemperature = Number(data);
        });
      };


      $scope.getViolations = function () {
        var vURL = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/temperature_store/threshold_violations';
        return $http.get(vURL).success(function (data) {
          $scope.thresholdViolations = data;
        });
      };


      $scope.getProfile = function () {
        var profileURL = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/sensor_profile/get_profile';
        return $http.get(profileURL).success(function (data) {
          $scope.name = data['name']
          $scope.phone = data['phone']
          $scope.location = data['location']
          $scope.temperatureThreshold = data['threshold']
        });
      };

      $scope.runAll = function () {
        $scope.getProfile();
        $scope.getAllTemps();
        $scope.getViolations();
        $scope.getCurrentTemp();
      };
    }
  ]);
