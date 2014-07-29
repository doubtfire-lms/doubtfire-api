var __indexOf = [].indexOf || function (item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (i in this && this[i] === item)
        return i;
    }
    return -1;
  };
angular.module('doubtfire.api', ['ngResource']).constant('api', 'http://ictwebsvm6.ict.swin.edu.au:8000/api').factory('resourcePlus', [
  '$resource',
  'api',
  'currentUser',
  function ($resource, api, currentUser) {
    return function (url, paramDefaults, actions) {
      var resource;
      url = api + url;
      actions = angular.extend({}, actions, {
        'create': { method: 'POST' },
        'update': { method: 'PUT' }
      });
      resource = $resource(url, paramDefaults, actions);
      delete resource['save'];
      angular.extend(resource.prototype, {
        $save: function () {
          return this[this.id != null ? '$update' : '$create'].apply(this, arguments);
        }
      });
      return resource;
    };
  }
]).factory('Project', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/projects/:id', { id: '@id' });
  }
]).factory('Unit', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/units/:id', { id: '@id' });
  }
]).factory('UnitRole', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/unit_roles/:id', { id: '@id' });
  }
]).factory('UserRole', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/user_roles/:id', { id: '@id' });
  }
]).factory('Convenor', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/users/convenors');
  }
]).factory('Tutor', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/users/tutors');
  }
]).factory('Tutorial', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/tutorials/:id', { id: '@id' });
  }
]).factory('Task', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/tasks/:id', { id: '@id' });
  }
]).factory('TaskDefinition', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/task_definitions/:id', { id: '@id' });
  }
]).factory('TaskFeedback', [
  'api',
  'currentUser',
  '$window',
  function (api, currentUser, $window) {
    this.getTaskUrl = function (task) {
      return '' + api + '/submission/task/' + task.id + '?auth_token=' + currentUser.authenticationToken;
    };
    this.openFeedback = function (task) {
      return $window.open(this.getTaskUrl(task), '_blank');
    };
    return this;
  }
]).factory('Students', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/students');
  }
]).factory('User', [
  'resourcePlus',
  function (resourcePlus) {
    return resourcePlus('/users/:id', { id: '@id' });
  }
]).service('UserCSV', [
  'api',
  '$window',
  'FileUploader',
  'currentUser',
  'alertService',
  function (api, $window, FileUploader, currentUser, alertService) {
    var csvUrl, fileUploader;
    csvUrl = '' + api + '/csv/users?auth_token=' + currentUser.authenticationToken;
    fileUploader = null;
    this.fileUploader = function (scope) {
      if (fileUploader == null && scope) {
        fileUploader = new FileUploader({
          scope: scope,
          url: csvUrl,
          method: 'POST',
          queueLimit: 1
        });
        fileUploader.onSuccessItem = function (item, response, status, headers) {
          if (response.length !== 0) {
            alertService.add('success', 'Added ' + response.length + ' users.', 2000);
            fileUploader.scope.users = fileUploader.scope.users.concat(response);
          } else {
            alertService.add('info', 'No users need to be added.', 2000);
          }
          return fileUploader.clearQueue();
        };
        fileUploader.onErrorItem = function (item, response, status, headers) {
          alertService.add('danger', 'File Upload Failed: ' + response.error, 2000);
          return fileUploader.clearQueue();
        };
      }
      return fileUploader;
    };
    this.downloadFile = function () {
      return $window.open(csvUrl, '_blank');
    };
    return this;
  }
]).service('TaskSubmission', [
  'api',
  '$window',
  'FileUploader',
  'currentUser',
  'alertService',
  function (api, $window, FileUploader, currentUser, alertService) {
    this.fileUploader = function (scope, task) {
      var extWhitelist, fileFilter, fileUploader, uploadUrl;
      uploadUrl = '' + api + '/submission/task/' + task.id + '?auth_token=' + currentUser.authenticationToken;
      fileUploader = new FileUploader({
        scope: scope,
        url: uploadUrl,
        method: 'POST',
        queueLimit: task.task_upload_requirements.length
      });
      fileUploader.task = task;
      extWhitelist = function (name, exts) {
        var ext, parts;
        parts = name.split('.');
        if (parts.length === 0) {
          return false;
        }
        ext = parts.pop();
        return __indexOf.call(exts, ext) >= 0;
      };
      fileFilter = function (acceptList, type, item) {
        var valid;
        valid = extWhitelist(item.name, acceptList);
        if (!valid) {
          alertService.add('info', '' + item.name + ' is not a valid ' + type + ' file (accepts <code>' + _.flatten(acceptList) + '</code>)', 6000);
        }
        return valid;
      };
      fileUploader.filters.push({
        name: 'is_code',
        fn: function (item) {
          return fileFilter([
            'pas',
            'cpp',
            'c',
            'cs',
            'h',
            'java'
          ], 'code', item);
        }
      });
      fileUploader.filters.push({
        name: 'is_document',
        fn: function (item) {
          return fileFilter(['pdf'], 'document', item);
        }
      });
      fileUploader.filters.push({
        name: 'is_image',
        fn: function (item) {
          return fileFilter([
            'png',
            'gif',
            'bmp',
            'tiff',
            'tif',
            'jpeg',
            'jpg'
          ], 'image', item);
        }
      });
      fileUploader.onUploadSuccess = function (response) {
        alertService.add('success', '' + fileUploader.task.task_name + ' uploaded successfully!', 2000);
        fileUploader.scope.close();
        return fileUploader.clearQueue();
      };
      fileUploader.onUploadFailure = function (response) {
        fileUploader.scope.close(response.error);
        alertService.add('danger', 'File Upload Failed: ' + response.error, 2000);
        return fileUploader.clearQueue();
      };
      fileUploader.uploadEnqueuedFiles = function () {
        var form, item, queue, xhr, _i, _len;
        queue = fileUploader.queue;
        xhr = new XMLHttpRequest();
        form = new FormData();
        this.isUploading = true;
        xhr.upload.onprogress = function (event) {
          fileUploader.progress = Math.round(event.lengthComputable ? event.loaded * 100 / event.total : 0);
          return fileUploader._render();
        };
        xhr.onreadystatechange = function () {
          if (xhr.readyState === 4) {
            fileUploader.isUploading = false;
            if (xhr.status === 201) {
              return fileUploader.onUploadSuccess(JSON.parse(xhr.responseText));
            } else {
              return fileUploader.onUploadFailure(JSON.parse(xhr.responseText));
            }
          }
        };
        for (_i = 0, _len = queue.length; _i < _len; _i++) {
          item = queue[_i];
          form.append(item.alias, item._file);
        }
        xhr.open(fileUploader.method, fileUploader.url, true);
        return xhr.send(form);
      };
      return fileUploader;
    };
    this.openTaskInNewWindow = function (task) {
      var win;
      win = $window.open(this.getTaskUrl(task), '_blank');
      return win.href = '';
    };
    return this;
  }
]).service('TaskCSV', [
  'api',
  '$window',
  'FileUploader',
  'currentUser',
  'alertService',
  function (api, $window, FileUploader, currentUser, alertService) {
    this.fileUploader = function (scope) {
      var fileUploader;
      fileUploader = new FileUploader({
        scope: scope,
        method: 'POST',
        url: '' + api + '/csv/task_definitions?auth_token=' + currentUser.authenticationToken + '&unit_id=0',
        queueLimit: 1
      });
      fileUploader.onBeforeUploadItem = function (item) {
        return item.url = fileUploader.url.replace(/unit_id=\d+/, 'unit_id=' + fileUploader.unit.id);
      };
      fileUploader.uploadTaskCSV = function (unit) {
        fileUploader.unit = unit;
        return fileUploader.uploadAll();
      };
      fileUploader.onSuccessItem = function (item, response, status, headers) {
        var diff, newTasks;
        newTasks = response;
        diff = newTasks.length - fileUploader.unit.task_definitions.length;
        alertService.add('success', 'Added ' + newTasks.length + ' tasks.', 2000);
        _.extend(fileUploader.scope.unit.task_definitions, response);
        return fileUploader.clearQueue();
      };
      fileUploader.onErrorItem = function (evt, response, item, headers) {
        alertService.add('danger', 'File Upload Failed: ' + response.error, 2000);
        return fileUploader.clearQueue();
      };
      return fileUploader;
    };
    this.downloadFile = function (unit) {
      return $window.open('' + api + '/csv/task_definitions?auth_token=' + currentUser.authenticationToken + '&unit_id=' + unit.id, '_blank');
    };
    return this;
  }
]).service('StudentEnrolmentCSV', [
  'api',
  '$window',
  'FileUploader',
  'currentUser',
  'alertService',
  function (api, $window, FileUploader, currentUser, alertService) {
    this.fileUploader = function (scope) {
      var fileUploader;
      fileUploader = new FileUploader({
        scope: scope,
        method: 'POST',
        url: '' + api + '/csv/units/0?auth_token=' + currentUser.authenticationToken,
        queueLimit: 1
      });
      fileUploader.onBeforeUploadItem = function (item) {
        return item.url = fileUploader.url.replace(/\d+\?/, '' + fileUploader.unit.id + '?');
      };
      fileUploader.uploadStudentEnrolmentCSV = function (unit) {
        fileUploader.unit = unit;
        return fileUploader.uploadAll();
      };
      fileUploader.onSuccessItem = function (item, response, status, headers) {
        var newStudents;
        newStudents = response;
        if (newStudents.length !== 0) {
          alertService.add('success', 'Enrolled ' + newStudents.length + ' students.', 2000);
          fileUploader.scope.unit.students = fileUploader.scope.unit.students.concat(newStudents);
        } else {
          alertService.add('info', 'No students need to be enrolled.', 2000);
        }
        return fileUploader.clearQueue();
      };
      fileUploader.onErrorItem = function (evt, response, item, headers) {
        alertService.add('danger', 'File Upload Failed: ' + response.error, 5000);
        return fileUploader.clearQueue();
      };
      return fileUploader;
    };
    this.downloadFile = function (unit) {
      return $window.open('' + api + '/csv/units/' + unit.id + '?auth_token=' + currentUser.authenticationToken, '_blank');
    };
    return this;
  }
]);