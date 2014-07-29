angular.module('utilService', []).filter('fromNow', function () {
  return function (date) {
    return moment(new Date(date)).fromNow();
  };
}).filter('titleize', function () {
  return function (input) {
    return _.string.titleize(input);
  };
}).filter('humanize', function () {
  return function (input) {
    return _.string.humanize(input);
  };
}).directive('autoFillSync', [
  '$timeout',
  function ($timeout) {
    return {
      require: 'ngModel',
      link: function (scope, elem, attrs, ngModel) {
        var origVal;
        origVal = elem.val();
        return $timeout(function () {
          var newVal;
          newVal = elem.val();
          if (ngModel.$pristine && origVal !== newVal) {
            return ngModel.$setViewValue(newVal);
          }
        }, 500);
      }
    };
  }
]);