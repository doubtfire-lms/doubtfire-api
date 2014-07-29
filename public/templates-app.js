angular.module('templates-app', ['common/header.tpl.html', 'common/sidebar.tpl.html', 'errors/not_found.tpl.html', 'errors/unauthorised.tpl.html', 'home/index.tpl.html', 'projects/partials/templates/lab-list.tpl.html', 'projects/partials/templates/progress-info.tpl.html', 'projects/partials/templates/project-modal.tpl.html', 'projects/partials/templates/task-feedback.tpl.html', 'projects/partials/templates/task-list.tpl.html', 'projects/projects-show.tpl.html', 'sessions/sign_in.tpl.html', 'sessions/sign_out.tpl.html', 'tasks/partials/templates/assess-task-modal.tpl.html', 'tasks/partials/templates/submit-task-modal.tpl.html', 'units/admin.tpl.html', 'units/partials/templates/enrol-student-context.tpl.html', 'units/partials/templates/enrol-student-modal.tpl.html', 'units/partials/templates/staff-admin-context.tpl.html', 'units/partials/templates/student-unit-context.tpl.html', 'units/partials/templates/student-unit-tasks.tpl.html', 'units/partials/templates/task-admin-context.tpl.html', 'units/partials/templates/task-edit-modal.tpl.html', 'units/partials/templates/tutor-unit-context.tpl.html', 'units/partials/templates/tutorial-admin-context.tpl.html', 'units/partials/templates/tutorial-modal.tpl.html', 'units/partials/templates/unit-admin-context.tpl.html', 'units/partials/templates/unit-create-modal.tpl.html', 'units/show.tpl.html', 'units/unit.tpl.html', 'users/admin.tpl.html', 'users/partials/templates/import-export-context.tpl.html', 'users/partials/templates/user-list-context.tpl.html', 'users/partials/templates/user-modal-context.tpl.html']);

angular.module("common/header.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("common/header.tpl.html",
    "<nav class=\"navbar navbar-default\" role=\"navigation\">\n" +
    "  <!-- Brand and toggle get grouped for better mobile display -->\n" +
    "  <div class=\"navbar-header\">\n" +
    "      <button type=\"button\" class=\"navbar-toggle\" ng-init=\"navCollapsed = true\" ng-click=\"navCollapsed = !navCollapsed\">\n" +
    "        <span class=\"sr-only\">Toggle navigation</span>\n" +
    "        <span class=\"icon-bar\"></span>\n" +
    "        <span class=\"icon-bar\"></span>\n" +
    "        <span class=\"icon-bar\"></span>\n" +
    "      </button>\n" +
    "    <a class=\"navbar-brand\" href=\"#\">Doubtfire</a>\n" +
    "  </div>\n" +
    "  <!-- Collect the nav links, forms, and other content for toggling -->\n" +
    "  <!-- Collect the nav links, forms, and other content for toggling -->\n" +
    "  <div class=\"collapse navbar-collapse\" ng-class=\"!navCollapsed && 'in'\" ng-click=\"navCollapsed = true\" ng-show=\"!navCollapsed\">\n" +
    "    <ul class=\"nav navbar-nav navbar-right\">\n" +
    "      <li class=\"dropdown\" ng-repeat=\"menu in menus | orderBy:'name'\">\n" +
    "        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"><span class=\"glyphicon glyphicon-{{menu.icon}}\"> {{menu.name}}</span><b class=\"caret\"></b></a>\n" +
    "        <ul class=\"dropdown-menu\">\n" +
    "          <li ng-repeat=\"link in menu.links | orderBy:'name'\"\n" +
    "              ng-class=\"{active: link.class === 'active'}\">\n" +
    "            <a href=\"{{link.url}}\">{{link.name}}</a>\n" +
    "          </li>\n" +
    "        </ul>\n" +
    "      </li>\n" +
    "\n" +
    "      <li class=\"dropdown\" ng-hide=\"projects.length == 0 && unitRoles.length == 0\">\n" +
    "        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"><span class=\"glyphicon glyphicon-book\"></span> Units <b class=\"caret\"></b></a>\n" +
    "        <ul class=\"dropdown-menu\">\n" +
    "          <li ng-hide=\"unitRoles.length == 0\" class=\"dropdown-header\">Units You Teach</li>\n" +
    "  				<li ng-repeat=\"unitRole in unitRoles | filter:isUniqueUnitRole\">\n" +
    "            <a href=\"#/units?unitRole={{unitRole.id}}\">{{unitRole.unit_name}}</a>\n" +
    "          </li>\n" +
    "          <li ng-hide=\"unitRoles.length == 0 || projects.length == 0\" class=\"divider\"></li>\n" +
    "          <li ng-hide=\"projects.length == 0\" class=\"dropdown-header\" ng-hide=\"{{projects.length}}\">Units You Study</li>\n" +
    "  				<li ng-repeat=\"project in projects\">\n" +
    "  				  <a href=\"#/projects/{{project.project_id}}\">{{project.unit_name}}</a>\n" +
    "  				</li>\n" +
    "        </ul>\n" +
    "      </li>\n" +
    "\n" +
    "      <li class=\"dropdown\" if-role=\"Admin\">\n" +
    "        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"><span class=\"glyphicon glyphicon-wrench\"></span> Administration<b class=\"caret\"></b></a>\n" +
    "        <ul class=\"dropdown-menu\">\n" +
    "          <li><a href=\"#/admin/units\">Manage Units</a></li>\n" +
    "          <li><a href=\"#/admin/users\">Manage Users</a></li>\n" +
    "        </ul>\n" +
    "      </li>\n" +
    "\n" +
    "      <li class=\"dropdown\" if-role=\"Convenor\">\n" +
    "        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"><span class=\"glyphicon glyphicon-wrench\"></span> Administration<b class=\"caret\"></b></a>\n" +
    "        <ul class=\"dropdown-menu\">\n" +
    "          <li><a href=\"#/admin/units\">Manage Units</a></li>\n" +
    "          <li><a href=\"#/admin/users\">Manage Users</a></li>\n" +
    "        </ul>\n" +
    "      </li>\n" +
    "\n" +
    "      <li class=\"dropdown\">\n" +
    "        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"><span class=\"glyphicon glyphicon-user\"></span> {{currentUser.name}} ({{currentUser.nickname}}) <b class=\"caret\"></b></a>\n" +
    "        <ul class=\"dropdown-menu\">\n" +
    "          <li><a href=\"#\" ng-click=\"openUserSettings()\">Profile</a></li>\n" +
    "          <li class=\"divider\"></li>\n" +
    "          <li><a href=\"#/sign_out\">Sign Out</a></li>\n" +
    "        </ul>\n" +
    "      </li>\n" +
    "    </ul>\n" +
    "  </div><!-- /.navbar-collapse -->\n" +
    "</nav>");
}]);

angular.module("common/sidebar.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("common/sidebar.tpl.html",
    "<div class=\"col-sm-3 well nav nav-stacked\" id=\"sidebar\">\n" +
    "	<div class=\"panel panel-default\" ng-show=\"unitRoles.length > 0\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Units You Teach</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "	  	<div ng-show=\"convenorRoles.length > 0\">\n" +
    "	  		<p>Convenor for</p>\n" +
    "			<div ng-repeat=\"unitRole in convenorRoles = unitRoles | filter:isConvenor\">\n" +
    "				<a href=\"#/units?unitRole={{unitRole.id}}\">{{unitRole.unit_name}}</a>\n" +
    "			</div>\n" +
    "		</div>\n" +
    "		<div ng-show=\"tutorRoles.length > 0\">\n" +
    "			<p>Tutor for</p>\n" +
    "			<div ng-repeat=\"unitRole in tutorRoles = unitRoles | filter:isTutor\">\n" +
    "				<a href=\"#/units?unitRole={{unitRole.id}}\">{{unitRole.unit_name}}</a>\n" +
    "			</div>\n" +
    "		</div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "\n" +
    "	<div class=\"panel panel-default\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Units You Study</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "		<div ng-repeat=\"project in projects\">\n" +
    "			<a href=\"#/projects/{{project.project_id}}\">{{project.unit_name}}</a>\n" +
    "		</div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "\n" +
    "\n" +
    "	<div class=\"panel panel-default\" if-role=\"Admin\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Administration</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "			<a href=\"#/admin/units\" if-role=\"Admin\">Manage Units</a>\n" +
    "		</div>\n" +
    "	</div>\n" +
    "</div>\n" +
    "");
}]);

angular.module("errors/not_found.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("errors/not_found.tpl.html",
    "<div class=\"container text-center\">\n" +
    "  <div class=\"error-container\">\n" +
    "    <i class=\"fa fa-question-circle\"></i>\n" +
    "    <h1>Not Found</h1>\n" +
    "    <p>This page doesn't exist.</p>\n" +
    "  </div>\n" +
    "</div>");
}]);

angular.module("errors/unauthorised.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("errors/unauthorised.tpl.html",
    "<div class=\"container text-center\">\n" +
    "  <div class=\"error-container\">\n" +
    "    <i class=\"fa fa-exclamation-triangle\"></i>\n" +
    "    <h1>Unauthorised</h1>\n" +
    "    <p>You do not have sufficient permissions to access this resource, or your session has expired.</p>\n" +
    "  </div>\n" +
    "</div>");
}]);

angular.module("home/index.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("home/index.tpl.html",
    "<div class=\"col-md-offset-2 col-md-8\">\n" +
    "	<div class=\"panel panel-default\" ng-show=\"unitRoles.length > 0\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Units You Teach</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "		<div ng-repeat=\"unitRole in convenorRoles = unitRoles\">\n" +
    "			<a href=\"#/units?unitRole={{unitRole.id}}\">{{unitRole.unit_name}}</a>\n" +
    "		</div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "\n" +
    "	<div class=\"panel panel-default\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Units You Study</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "  		<div ng-repeat=\"project in projects\">\n" +
    "  			<a href=\"#/projects/{{project.project_id}}\">{{project.unit_name}}</a>\n" +
    "  		</div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "\n" +
    "	<div class=\"panel panel-default\" if-role=\"Admin\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Administration</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "		<div><a href=\"#/admin/units\" if-role=\"Admin\">Manage Units</a></div>\n" +
    "		<div><a href=\"#/admin/users\" if-role=\"Admin\">Manage Users</a></div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "\n" +
    "	<div class=\"panel panel-default\" if-role=\"Convenor\">\n" +
    "	  <div class=\"panel-heading\">\n" +
    "	    <h4 class=\"panel-title\">Administration</h4>\n" +
    "	  </div>\n" +
    "	  <div class=\"panel-body\">\n" +
    "			<div><a href=\"#/admin/units\" if-role=\"Admin\">Manage Units</a></div>\n" +
    "	  </div>\n" +
    "	</div>\n" +
    "</div>");
}]);

angular.module("projects/partials/templates/lab-list.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/partials/templates/lab-list.tpl.html",
    "<div>\n" +
    "  <!-- ensure content remains in root div tag -->\n" +
    "  <div class=\"table-responsive\">\n" +
    "    <table class=\"table table-condensed table-hover\">\n" +
    "      <thead>\n" +
    "        <tr>\n" +
    "          <th>Lab Code</th>\n" +
    "          <th><a href=\"\" ng-click=\"sortOrder='meeting_day'; reverse=!reverse\">Day</a></th>\n" +
    "          <th>Time</th>\n" +
    "          <th>Room</th>\n" +
    "          <th>Tutor</th>\n" +
    "          <th>Assigned</th>\n" +
    "        </tr>\n" +
    "      </thead>\n" +
    "      <tbody>\n" +
    "        <tr ng-repeat=\"tutorial in unit.tutorials | orderBy:sortOrder:reverse\">\n" +
    "          <td>{{tutorial.abbreviation}}</td>\n" +
    "          <td>{{tutorial.meeting_day}}</td>\n" +
    "          <td>{{tutorial.meeting_time | date: 'shortTime'}}</td>\n" +
    "          <td>{{tutorial.meeting_location}}</td>\n" +
    "          <td>{{tutorial.tutor_name}}</td>\n" +
    "          <td ng-if=\"project.tute == tutorial.id\"><button type=\"button\" class=\"btn btn-info\"><span class=\"glyphicon glyphicon-ok\"></span> </button>\n" +
    "          </td>\n" +
    "          <td ng-if=\"project.tute != tutorial.id\"><button type=\"button\" class=\"btn btn-warning\" ng-click =\"setTutorial(tutorial.id)\"><span class=\"glyphicon glyphicon-minus\"></span></button>\n" +
    "          </td>\n" +
    "        </tr>\n" +
    "      </tbody>\n" +
    "      <tfoot if-role=\"Tutor Convenor Admin\">\n" +
    "        <tr>\n" +
    "          <td></td>\n" +
    "          <td></td>\n" +
    "          <td></td>\n" +
    "          <td></td>\n" +
    "          <td></td>\n" +
    "          <td><button type=\"button\" class=\"btn btn-danger\" ng-click=\"setTutorial(-1)\"><span class=\"glyphicon glyphicon-remove\"></span></button></td>\n" +
    "        </tr>\n" +
    "      </tfoot>\n" +
    "    </table>\n" +
    "  </div>\n" +
    "</div>");
}]);

angular.module("projects/partials/templates/progress-info.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/partials/templates/progress-info.tpl.html",
    "<div ng-if=\"unitLoaded\">\n" +
    "  <div class=\"col-md-4 pull-right\">\n" +
    "    <h3 class=\"lead\">Task Completion</h3>\n" +
    "    <student-unit-tasks project=\"project\" on-change=\"updateBurndownChart\" student-project-id=\"studentProjectId\" task-def=\"taskDef\" unit=\"unit\" assessing-unit-role=\"assessingUnitRole\"></student-unit-tasks>\n" +
    "    </div>\n" +
    "  <div class=\"col-md-8 pull-left\">\n" +
    "    <h3 class=\"lead\">Burndown Chart</h3>\n" +
    "    <div id=\"burndownChart\" ng-if=\"projectLoaded\">\n" +
    "  		<nvd3-line-chart\n" +
    "  			data=\"burndownData\"\n" +
    "  			id=\"burndownId\"\n" +
    "  			width=\"550\"\n" +
    "  			height=\"350\"\n" +
    "  			showXAxis=\"true\"\n" +
    "  			showYAxis=\"true\"\n" +
    "  			showLegend=\"true\"\n" +
    "  			tooltips=\"true\"\n" +
    "  			useInteractiveGuideline=\"true\"\n" +
    "  			margin=\"{left:80,top:50,bottom:50,right:10}\"\n" +
    "  			xAxisTickFormat=\"xAxisTickFormat_Date_Format()\"\n" +
    "  			yAxisLabel=\"Tasks Remaining\"\n" +
    "  			yAxisTickFormat=\"yAxisTickFormat_Percent_Format()\"\n" +
    "  			color=\"colorFunction()\"\n" +
    "  			legendColor=\"colorFunction()\"\n" +
    "  			y=\"yAxisClipNegBurndown()\"\n" +
    "  			x=\"xAxisClipNegBurndown()\"\n" +
    "  			forcex=\"[{{lateEndDate()}}]\">\n" +
    "  			<svg></svg>\n" +
    "  		</nvd3-line-chart>\n" +
    "  	</div>\n" +
    "  </div>\n" +
    "</div>\n" +
    "\n" +
    "<!-- 	    <div ng-show=\"showBack\">\n" +
    "	    	<a href=\"#/units?unitRole={{assessingUnitRole.id}}\">Back</a>\n" +
    "	    </div>\n" +
    " -->");
}]);

angular.module("projects/partials/templates/project-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/partials/templates/project-modal.tpl.html",
    "<div>\n" +
    "	<form ng-submit=\"saveUnit()\">\n" +
    "		<div class=\"modal-header\">\n" +
    "			<h3>Create Unit</h3>\n" +
    "		</div>\n" +
    "		<div class=\"modal-body\">\n" +
    "			<h4>Details</h4>\n" +
    "			<div class=\"form-group\">\n" +
    "				<div class=\"form-inline\">\n" +
    "					<div class=\"form-group\">\n" +
    "						<label>Code:</label>\n" +
    "						<input type=\"text\" ng-model=\"unit.code\">\n" +
    "					</div>\n" +
    "					<div class=\"form-group\">\n" +
    "						<label>Name:</label>\n" +
    "						<input type=\"text\" ng-model=\"unit.name\">\n" +
    "					</div>\n" +
    "				</div>\n" +
    "			</div>\n" +
    "			<div class=\"form-group\">\n" +
    "				<label>Description:</label>\n" +
    "				<textarea ng-model=\"unit.description\"></textarea>\n" +
    "			</div>\n" +
    "\n" +
    "			<div class=\"form-group\">\n" +
    "				<div class=\"form-inline\">\n" +
    "					<div class=\"form-group\">\n" +
    "						<input type=\"text\" class=\"form-control\" datepicker-popup=\"{{format}}\" ng-model=\"unit.start_date\" is-open=\"startDateOpened\" ng-required=\"true\" close-text=\"Close\" />\n" +
    "						<span class=\"input-group-btn\">\n" +
    "						<button class=\"btn btn-default\" ng-click=\"open($event)\"><i class=\"glyphicon glyphicon-calendar\"></i></button>\n" +
    "						</span>\n" +
    "					</div>\n" +
    "					<div class=\"form-group\">\n" +
    "						<input type=\"text\" class=\"form-control\" datepicker-popup=\"{{format}}\" ng-model=\"unit.end_date\" is-open=\"endDateOpened\"ng-required=\"true\" close-text=\"Close\" />\n" +
    "						<span class=\"input-group-btn\">\n" +
    "						<button class=\"btn btn-default\" ng-click=\"open($event)\"><i class=\"glyphicon glyphicon-calendar\"></i></button>\n" +
    "						</span>\n" +
    "					</div>\n" +
    "				</div>\n" +
    "			</div>\n" +
    "\n" +
    "			<h4>Convenors</h4>\n" +
    "			<ul ng-show=\"unit.convenors.length > 0\">\n" +
    "				<li ng-repeat=\"convenor in unit.convenors\">\n" +
    "					{{convenor.user.name}} <a href ng-click=\"removeConvenor(convenor)\">Remove</a>\n" +
    "				</li>\n" +
    "			</ul>\n" +
    "\n" +
    "			<div class=\"form-group\">\n" +
    "				<input ng-model=\"modalState.selectedConvenor\" typeahead=\"convenor as convenor.user.name for convenor in availableConvenors\">\n" +
    "				<button type=\"button\" ng-click=\"addSelectedConvenor()\">\n" +
    "					Add\n" +
    "				</button>\n" +
    "			</div>\n" +
    "		</div>\n" +
    "		<div class=\"modal-footer\">\n" +
    "			<button type=\"submit\" class=\"btn btn-primary\">\n" +
    "				Create Unit\n" +
    "			</button>\n" +
    "		</div>\n" +
    "	</form>\n" +
    "</div>");
}]);

angular.module("projects/partials/templates/task-feedback.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/partials/templates/task-feedback.tpl.html",
    "<div>\n" +
    "  <div class=\"pull-left list-group col-md-2\">\n" +
    "    <a ng-repeat=\"task in submittedTasks\" ng-class=\"{'active' : task == activeTask }\" class=\"list-group-item text-center\" ng-click=\"setActiveTask(task)\">{{task.task_abbr}}</a>\n" +
    "  </div>\n" +
    "  <div class=\"pull-right col-md-10 well\">\n" +
    "    <div class=\"col-md-7\">\n" +
    "      <h3 class=\"lead\">{{activeTask.task_name}}</h3>\n" +
    "    </div><!--/task-details-->\n" +
    "    \n" +
    "    <div class=\"pull-right text-center col-md-1 well-sm task-status {{statusClass(activeTask.status)}}\" tooltip-placement=\"right\" tooltip=\"{{activeStatusData().label}}\">\n" +
    "      <i class=\"{{activeStatusData().icon}} fa-3x\"></i>\n" +
    "    </div><!--/task-status-->\n" +
    "\n" +
    "    <div class=\"col-md-12\">\n" +
    "      <div class=\"panel panel-default\">\n" +
    "        <div class=\"panel-heading\" style=\"height: 60px\">\n" +
    "          <h4 class=\"pull-left\">{{pageNo}} of {{pdf.numPages}}</h4>\n" +
    "          <div class=\"pull-right btn-group\">\n" +
    "            <button type=\"button\" class=\"btn btn-default\" ng-disabled=\"pageNo == 1\" ng-click=\"prevPage()\">\n" +
    "              <span class=\"glyphicon glyphicon-chevron-left\"></span>\n" +
    "            </button>\n" +
    "            <button type=\"button\" class=\"btn btn-default\" ng-disabled=\"pageNo == pdf.numPages\" ng-click=\"nextPage()\">\n" +
    "              <span class=\"glyphicon glyphicon-chevron-right\"></span>\n" +
    "            </button>\n" +
    "          </div>\n" +
    "        </div>\n" +
    "        <div class=\"panel-body\">\n" +
    "          <a href=\"{{activeTaskUrl()}}\">\n" +
    "            <canvas id=\"pdf\"></canvas>\n" +
    "          </a>\n" +
    "        </div>\n" +
    "        <div class=\"panel-footer\" style=\"height: 60px\" ng-hide=\"activeTask.status == 'ready_to_mark'\">\n" +
    "          <div class=\"pull-left text-muted\">\n" +
    "            <strong>Note:</strong> Comments are viewable once PDF is downloaded {{activeTask.status}}\n" +
    "          </div>\n" +
    "          <div class=\"pull-right btn-group\">\n" +
    "            <a href=\"{{activeTaskUrl()}}\" class=\"btn btn-success\">\n" +
    "              <span class=\"glyphicon glyphicon-cloud-download\"></span>\n" +
    "            </a>\n" +
    "          </div>\n" +
    "        </div>\n" +
    "      </div>\n" +
    "    </div><!--/pdf-->\n" +
    "\n" +
    "  </div>\n" +
    "\n" +
    "</div>");
}]);

angular.module("projects/partials/templates/task-list.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/partials/templates/task-list.tpl.html",
    "<div>\n" +
    "  <accordion close-others=\"oneAtATime\">\n" +
    "    <accordion-group heading=\"{{task_def.name}} : {{task_def.abbr}}\" ng-repeat=\"task_def in unit.task_definitions\">\n" +
    "      <p>{{task_def.desc}}</p>\n" +
    "      <p>Due Date : {{task_def.target_date}}</p>\n" +
    "    </accordion-group>\n" +
    "  </accordion>\n" +
    "</div>");
}]);

angular.module("projects/projects-show.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("projects/projects-show.tpl.html",
    "<ul class=\"breadcrumb\">\n" +
    "  	<li><a href=\"#/home\">Home</a></li>\n" +
    "  	<li class=\"active\">{{unit.name}}</li>\n" +
    "</ul>\n" +
    "\n" +
    "<tabset class=\"col-md-offset-2 col-md-8\">\n" +
    "  <h2>{{unit.name}} <small>{{unit.code}}</small><p class=\"lead\"> {{project.student_name}} </p></h2>\n" +
    "  <tab heading=\"Progress\">\n" +
    "    <progress-info></progress-info>\n" +
    "  </tab>\n" +
    "  <tab ng-show=\"submittedTasks.length > 0\" heading=\"Feedback\">\n" +
    "    <task-feedback ng-if=\"unitLoaded\"></task-feedback>\n" +
    "  </tab>\n" +
    "  <tab heading=\"Labs\">\n" +
    "    <lab-list></lab-list>\n" +
    "  </tab>\n" +
    "</tabset>\n" +
    "");
}]);

angular.module("sessions/sign_in.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("sessions/sign_in.tpl.html",
    "<div class=\"container landing-page\">\n" +
    "	<h1>Doubtfire</h1>\n" +
    "	<form class=\"form-signin well\" name=\"form\" ng-submit=\"signIn()\">\n" +
    "		<input class=\"form-control\" name=\"username\" type=\"username\" placeholder=\"Username\" ng-model=\"session.username\" auto-fill-sync required />\n" +
    "		<input class=\"form-control\" name=\"password\" type=\"password\" placeholder=\"Password\" ng-model=\"session.password\" password-validate auto-fill-sync required />\n" +
    "    <div class=\"checkbox\">\n" +
    "  		<label>\n" +
    "  			<input type=\"checkbox\" value=\"remember-me\"> Remember me\n" +
    "  		</label>\n" +
    "    </div>\n" +
    "		<input class=\"btn btn-lg btn-primary btn-block\" type=\"submit\" value=\"Sign In\" />\n" +
    "	</form>\n" +
    "</div>\n" +
    "\n" +
    "");
}]);

angular.module("sessions/sign_out.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("sessions/sign_out.tpl.html",
    "<div class=\"container text-center\">\n" +
    "  <div class=\"sign-out-container\">\n" +
    "    <i class=\"fa fa-sign-out\"></i>\n" +
    "    <h1>Signing out...</h1>\n" +
    "  </div>\n" +
    "</div>\n" +
    "");
}]);

angular.module("tasks/partials/templates/assess-task-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("tasks/partials/templates/assess-task-modal.tpl.html",
    "<form>\n" +
    "	<div class=\"modal-header\">\n" +
    "		<h3>\n" +
    "			Assess Task<span class=\"fa fa-graduation-cap fa-2x pull-right\"></span>\n" +
    "		</h3>\n" +
    "		<h4>{{task.task_name}}</h4>\n" +
    "		<p>{{task.task_desc}}</p>\n" +
    "	</div>\n" +
    "	<div class=\"modal-body\">\n" +
    "\n" +
    "		<div class=\"btn-group btn-group-justified task-status\">\n" +
    "			<label ng-repeat=\"action in taskEngagementConfig.all\" \n" +
    "				class=\"btn {{action.taskClass}} {{activeClass(action.status)}}\" \n" +
    "				ng-model=\"task.status\" \n" +
    "				btn-radio=\"action.status\" \n" +
    "				ng-click=\"triggerTransition(action.status)\">{{action.label}} <i class=\"{{action.iconClass}}\"></i>\n" +
    "			</label>\n" +
    "		</div>\n" +
    "		<br />\n" +
    "		<div class=\"btn-group btn-group-justified task-status\">\n" +
    "			<label ng-repeat=\"action in taskEngagementConfig.tutorTriggers\" \n" +
    "				class=\"btn {{action.taskClass}} {{activeClass(action.status)}}\" \n" +
    "				ng-model=\"task.status\" \n" +
    "				btn-radio=\"action.status\"\n" +
    "				ng-class=\"role == 'Student' ? 'disabled' : ''\"\n" +
    "				ng-click=\"triggerTransition(action.status)\">{{action.label}} <i class=\"{{action.iconClass}}\"></i>\n" +
    "			</label>\n" +
    "		</div>\n" +
    "		<br />\n" +
    "		<div class=\"btn-group btn-group-justified task-status\">\n" +
    "			<label ng-repeat=\"action in taskEngagementConfig.complete\"\n" +
    "				class=\"btn {{action.taskClass}} {{activeClass(action.status)}}\" \n" +
    "				ng-model=\"task.status\" \n" +
    "				btn-radio=\"action.status\" \n" +
    "				disabled=\"disabled\">{{action.label}} <i class=\"{{action.iconClass}}\"></i>\n" +
    "			</label>\n" +
    "		</div>\n" +
    "	</div>\n" +
    "	<div class=\"modal-footer\">\n" +
    "	</div>\n" +
    "</form>");
}]);

angular.module("tasks/partials/templates/submit-task-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("tasks/partials/templates/submit-task-modal.tpl.html",
    "<form ng-submit=\"submitUpload()\">\n" +
    "	<div class=\"modal-header\">\n" +
    "		<h3>\n" +
    "			{{uploadRequirements.length}} File{{uploadRequirements.length > 1 ? \"s\" : \"\"}} Required <span class=\"fa fa-cloud-upload fa-2x pull-right\"></span>\n" +
    "		</h3>\n" +
    "		<h4>{{task.task_name}}</h4>\n" +
    "		<p> To mark this task as <strong>Ready To Mark</strong>, you must provide the following files to generate your submission document. </p>\n" +
    "	</div>\n" +
    "	<div class=\"modal-body\">\n" +
    "    <button ng-hide=\"fileUploader.isUploading || fileUploader.queue.length == 0\" class=\"btn btn-sm btn-default pull-right\" ng-click=\"clearUploads()\"><span class=\"glyphicon glyphicon-ban-circle\"></span></button>\n" +
    "    <div ng-repeat=\"upload in uploadRequirements\" ng-hide=\"fileUploader.isUploading\">\n" +
    "      <h5>{{$index + 1}}. {{upload.name}}</h5>\n" +
    "      <input ng-hide=\"fileUploader.isHTML5\" options=\"{ alias: 'file{{$index}}' }\" type=\"file\" uploader=\"fileUploader\" ng-required=\"!fileUploader.isHTML5\" nv-file-select />\n" +
    "      <div ng-show=\"fileUploader.queue.length == $index\" uploader=\"fileUploader\" ng-show=\"fileUploader.isHTML5 && !(fileUploader.queue.length > $index)\" class=\"drop well\" over-class=\"file-over-hover\" options=\"{ alias: 'file{{$index}}' }\" nv-file-drop nv-file-over filters=\"is_{{upload.type}}\">\n" +
    "        <p class=\"fa fa-file-{{upload.type == 'document' ? 'pdf' : upload.type}}-o fa-3x\"></p>\n" +
    "        <br/>\n" +
    "        Drop {{upload.type}} here\n" +
    "      </div>\n" +
    "      <p ng-show=\"fileUploader.queue.length > $index\"class=\"form-control-static\">{{fileUploader.queue[$index].file.name}} <span class=\"glyphicon glyphicon-file\"></span></p>\n" +
    "    </div>\n" +
    "    <div class=\"form-group\">\n" +
    "      <input ng-hide=\"fileUploader.isUploading || fileUploader.queue.length != uploadRequirements.length\" type=\"submit\" class=\"btn btn-primary form-control col-sm-4 col-sm-offset-8\" value=\"Generate Submission\" />\n" +
    "      <br/>\n" +
    "      <div ng-show=\"fileUploader.isUploading\">\n" +
    "        <progressbar class=\"progress-striped active\" value=\"fileUploader.progress\"></progressbar>\n" +
    "        <p class=\"help-block text-center\" ng-show=\"fileUploader.progress == 100\">\n" +
    "          Please wait for the server to generate your submission document...\n" +
    "        </p>\n" +
    "      </div>\n" +
    "    </div>\n" +
    "	</div>\n" +
    "	<div class=\"modal-footer\">\n" +
    "	</div>\n" +
    "</form>");
}]);

angular.module("units/admin.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/admin.tpl.html",
    "<div class=\"col-md-offset-2 col-md-8\">\n" +
    "	<div class=\"panel panel-default\" ng-show=\"units.length > 0\">\n" +
    "    <div class=\"panel-heading\">\n" +
    "      <h4 class=\"panel-title\">Units</h4>\n" +
    "    </div>\n" +
    "   <table class=\"table table-condensed table-hover\">\n" +
    "     <thead>\n" +
    "       <tr> \n" +
    "         <th>Code</th>\n" +
    "         <th>Name</th>\n" +
    "         <th>Start Date</th>\n" +
    "         <th>End Date</th>\n" +
    "         <th>Active</th>\n" +
    "       </tr>\n" +
    "     </thead>\n" +
    "     <tbody>\n" +
    "     <tr ng-repeat=\"unit in units\" ng-click=\"showUnit(unit)\" >\n" +
    "       <td>{{unit.code}}</td>\n" +
    "       <td>{{unit.name}}</td>\n" +
    "       <td>{{unit.start_date | date: short }}</td>\n" +
    "       <td>{{unit.end_date | date: short }}</td>\n" +
    "       <td>\n" +
    "         <span ng-show=\"unit.active\" class=\"glyphicon glyphicon-ok text-success\"></span>\n" +
    "         <span ng-hide=\"unit.active\" class=\"glyphicon glyphicon-remove\n" +
    "           text-danger\" ></span>\n" +
    "       </td>\n" +
    "     </tr>\n" +
    "     </tbody>\n" +
    "   </table>\n" +
    "  </div>\n" +
    "  <button class=\"btn btn-primary\" ng-click=\"createUnit()\">Create Unit</button>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/partials/templates/enrol-student-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/enrol-student-context.tpl.html",
    "<div>\n" +
    "  <h4>Batch Import / Export</h4>\n" +
    "  <form class=\"form-horizontal\" ng-submit=\"submitSEUpload()\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Upload</label>\n" +
    "      <input uploader=\"seFileUploader\" ng-hide=\"seFileUploader.isHTML5\" type=\"file\" class=\"col-sm-7\" accept=\"text/csv\" ng-required=\"!seFileUploader.isHTML5\" nv-file-select />\n" +
    "      <div uploader=\"seFileUploader\"  ng-show=\"seFileUploader.isHTML5 && seFileUploader.queue.length == 0\" class=\"drop well col-sm-7\" nv-file-over nv-file-drop>\n" +
    "        Drop CSV here\n" +
    "      </div>\n" +
    "	    <p ng-show=\"seFileUploader.queue.length == 1\"class=\"form-control-static\">{{seFileUploader.queue[0].file.name}} <span class=\"glyphicon glyphicon-file\"></span></p>\n" +
    "    </div>\n" +
    "    <div class=\"form-group\">\n" +
    "      <input ng-hide=\"seFileUploader.isUploading || seFileUploader.queue.length == 0\" type=\"submit\" class=\"btn btn-primary form-control col-sm-2 col-sm-offset-3\" value=\"Import\" />\n" +
    "      <div class=\"col-sm-offset-3 col-sm-6\" ng-show=\"seFileUploader.isUploading\">\n" +
    "        <progressbar class=\"progress-striped active\" value=\"seFileUploader.progress\"></progressbar>\n" +
    "        <p class=\"help-block text-center\" ng-show=\"seFileUploader.progress == 100\">\n" +
    "          Please wait for the server to insert the students...\n" +
    "        </p>\n" +
    "      </div>\n" +
    "    </div>\n" +
    "  <form class=\"form-horizontal\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Download</label>\n" +
    "      <button ng-click=\"requestSEExport()\" class=\"btn btn-primary form-control col-sm-2\">Export</button>\n" +
    "    </div>\n" +
    "  </form><!--/batch-io-->\n" +
    "\n" +
    "  <h4>All Enrolled Students</h4>\n" +
    "  <table class=\"table table-condensed table-hover\">\n" +
    "    <thead>\n" +
    "      <tr> \n" +
    "        <th>Username</th>\n" +
    "        <th>First Name</th>\n" +
    "        <th>Last Name</th>\n" +
    "        <th>Email</th>\n" +
    "        <th>Tutorial</th>\n" +
    "      </tr>\n" +
    "    </thead>\n" +
    "    <tbody>\n" +
    "      <tr ng-repeat=\"student in unit.students | startFrom:(currentPage - 1) * pageSize | limitTo: pageSize\">\n" +
    "        <td>{{student.username}}</td>\n" +
    "        <td>{{student.first_name}}</td>\n" +
    "        <td>{{student.last_name}}</td>\n" +
    "        <td><a href=\"mailto:{{student.email}}\">{{student.email}}</a></td>\n" +
    "        <td>{{student.tutorial}}</td>\n" +
    "        <td>\n" +
    "          <ol style=\"margin-left: 0; padding-left: 0;\"  ng-hide=\"task.upload_requirements.length == 0\">\n" +
    "            <li ng-repeat=\"upreq in task.upload_requirements\">{{upreq.name}} ({{upreq.type}})</li>\n" +
    "          </ol>\n" +
    "          <span ng-show=\"task.upload_requirements.length == 0\">No Files To Upload</span>\n" +
    "        </td>\n" +
    "      </tr>\n" +
    "    </tbody>\n" +
    "  </table><!--/task-table-->\n" +
    "\n" +
    "  <pagination total-items=\"unit.students.length\" ng-model=\"currentPage\" items-per-page=\"pageSize\" max-size=\"maxSize\" class=\"pagination-sm\" boundary-links=\"true\" rotate=\"false\"></pagination>\n" +
    "</div>");
}]);

angular.module("units/partials/templates/enrol-student-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/enrol-student-modal.tpl.html",
    "<div>\n" +
    "  <div class=\"modal-header\">\n" +
    "    <h3>Enrol Student</h3>\n" +
    "  </div>\n" +
    "  <div class=\"modal-body\">\n" +
    "    <form class=\"form-horizontal\">\n" +
    "      <div class=\"form-group\" required>\n" +
    "        <label class=\"col-sm-3 control-label\">Student ID</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" placeholder=\"Student ID\" ng-model=\"student_id\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" required>\n" +
    "        <label class=\"col-sm-3 control-label\">Tutorial</label>\n" +
    "        <input id=\"searchbar\" class=\"col-sm-7 form-control\" placeholder=\"Tutorial Code\" type=\"search\" ng-model=\"tutorial\" typeahead=\"tutorial as tutorial.abbreviation for tutorial in unit.tutorials\" />\n" +
    "      </div>\n" +
    "    </form>\n" +
    "  </div>\n" +
    "  <div class=\"modal-footer text-right\">\n" +
    "    <input type=\"button\" ng-click=\"enrolStudent(student_id, tutorial)\" class=\"btn btn-primary\" value=\"Save\" />\n" +
    "  </div>\n" +
    "</div>");
}]);

angular.module("units/partials/templates/staff-admin-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/staff-admin-context.tpl.html",
    "<form class=\"form-horizontal\">\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"convenors\">Add Staff</label>\n" +
    "    <div class=\"col-md-10 input-group\">\n" +
    "      <input class=\"form-control\" id=\"convenors\" placeholder=\"Name\" ng-model=\"selectedStaff\" typeahead=\"staff as\n" +
    "      staff.full_name for staff in staff | filter: $viewValue | filter: filterStaff\"> \n" +
    "      \n" +
    "      <span class=\"input-group-btn\">\n" +
    "        <button class=\"btn btn-default\" ng-click=\"addSelectedStaff()\">\n" +
    "          <i class=\"glyphicon glyphicon-plus\"></i>\n" +
    "        </button>\n" +
    "      </span>\n" +
    "    </div>\n" +
    "  </div>\n" +
    "\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"currentConvenors\" >Current Staff</label>\n" +
    "    <ul class=\"col-md-10 input-group\" ng-show=\"unit.staff.length > 0\">\n" +
    "      <li class=\"list-group-item\" ng-repeat=\"staff in unit.staff\">\n" +
    "        \n" +
    "        <span class=\"badge btn btn-default\" ng-click=\"removeStaff(staff)\">\n" +
    "            <i class=\"glyphicon glyphicon-remove\"></i>\n" +
    "        </span>\n" +
    "        \n" +
    "        <strong>{{staff.name}}</strong>\n" +
    "        <br/>\n" +
    "      \n" +
    "        <label name=\"staffRole\" class=\"radio-inline\" for=\"radio-tutor-{{staff.id}}\">\n" +
    "          <input type=\"radio\" id=\"radio-tutor-{{staff.id}}\" value=\"Tutor\" ng-model=\"staff.role\" ng-click=\"changeRole(staff,2)\"/>Tutor\n" +
    "        </label>\n" +
    "        \n" +
    "        <label name=\"staffRole\" class=\"radio-inline\" for=\"radio-convenor-{{staff.id}}\">\n" +
    "          <input type=\"radio\" id=\"radio-convenor-{{staff.id}}\" value=\"Convenor\" ng-model=\"staff.role\" ng-click=\"changeRole(staff,3)\" />Convenor      \n" +
    "        </label>\n" +
    "      \n" +
    "      </li>\n" +
    "    </ul>\n" +
    "  </div>\n" +
    "</form>\n" +
    "\n" +
    "");
}]);

angular.module("units/partials/templates/student-unit-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/student-unit-context.tpl.html",
    "<!-- <div>\n" +
    "    <h2>{{unit.name}}</h2>\n" +
    "    <student-unit-tasks student-project-id=\"unitRole.project_id\" task-def=\"taskDef\" unit=\"unit\" assessing-unit-role=\"assessingUnitRole\"></student-unit-tasks>\n" +
    "\n" +
    "    <div ng-show=\"showBack\">\n" +
    "    	<a href=\"#/units?unitRole={{assessingUnitRole.id}}\">Back</a>\n" +
    "    </div>\n" +
    "</div>\n" +
    " -->");
}]);

angular.module("units/partials/templates/student-unit-tasks.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/student-unit-tasks.tpl.html",
    "<ul class=\"project-task-bar\">\n" +
    "	<li ng-repeat=\"task in tasks | orderBy:'-id'\">\n" +
    "	    <a class=\"btn btn-default task-status {{statusClass(task.status)}}\" ng-click=\"showAssessTaskModal(task)\" tooltip-popup-delay='200' tooltip-placement=\"bottom\" tooltip=\"{{task.task_name}}: {{statusText(task.status)}}\">{{task.task_abbr}}</a>\n" +
    "	</li>\n" +
    "</ul>");
}]);

angular.module("units/partials/templates/task-admin-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/task-admin-context.tpl.html",
    "<div>\n" +
    "  <h4>All Tasks</h4>\n" +
    "  <table class=\"table table-condensed table-hover\">\n" +
    "    <thead>\n" +
    "      <tr> \n" +
    "        <th>Abbr</th>\n" +
    "        <th>Name</th>\n" +
    "        <th>Description</th>\n" +
    "        <th>Target Date</th>\n" +
    "        <th>Weighting</th>\n" +
    "        <th>Required</th>\n" +
    "        <th>File Upload Requirements</th>\n" +
    "      </tr>\n" +
    "    </thead>\n" +
    "    <tbody>\n" +
    "      <tr ng-repeat=\"task in unit.task_definitions | startFrom:(currentPage - 1) * pageSize | limitTo: pageSize\" ng-click=\"editTask(task)\">\n" +
    "        <td>{{task.abbr}}</td>\n" +
    "        <td>{{task.name}}</td>\n" +
    "        <td style=\"max-width:150px\">{{task.desc}}</td>\n" +
    "        <td>{{task.target_date | date:'d MMM yyyy'}}</td>\n" +
    "        <td>{{task.weight}}</td>\n" +
    "        <td>{{task.required}}</td>\n" +
    "        <td>\n" +
    "          <ol style=\"margin-left: 0; padding-left: 0;\"  ng-hide=\"task.upload_requirements.length == 0\">\n" +
    "            <li ng-repeat=\"upreq in task.upload_requirements\">{{upreq.name}} ({{upreq.type}})</li>\n" +
    "          </ol>\n" +
    "          <span ng-show=\"task.upload_requirements.length == 0\">No Files To Upload</span>\n" +
    "        </td>\n" +
    "      </tr>\n" +
    "    </tbody>\n" +
    "  </table><!--/task-table-->\n" +
    "    \n" +
    "  <pagination total-items=\"unit.task_definitions.length\" ng-model=\"currentPage\" items-per-page=\"pageSize\" max-size=\"maxSize\" class=\"pagination-sm\" boundary-links=\"true\" rotate=\"false\"></pagination>\n" +
    "  <button class=\"btn btn-success pull-right\" ng-click=\"createTask()\">Create Task</button>\n" +
    "\n" +
    "  <h4>Batch Import / Export</h4>\n" +
    "  <form class=\"form-horizontal\" ng-submit=\"submitTasksUpload()\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Upload</label>\n" +
    "      <input uploader=\"tasksFileUploader\" ng-hide=\"tasksFileUploader.isHTML5\" type=\"file\" class=\"col-sm-7\" accept=\"text/csv\" ng-required=\"!tasksFileUploader.isHTML5\" nv-file-select />\n" +
    "      <div uploader=\"tasksFileUploader\"  ng-show=\"tasksFileUploader.isHTML5 && tasksFileUploader.queue.length == 0\" class=\"drop well col-sm-7\" nv-file-over nv-file-drop>\n" +
    "        Drop CSV here\n" +
    "      </div>\n" +
    "	    <p ng-show=\"tasksFileUploader.queue.length == 1\"class=\"form-control-static\">{{tasksFileUploader.queue[0].file.name}} <span class=\"glyphicon glyphicon-file\"></span></p>\n" +
    "    </div>\n" +
    "    <div class=\"form-group\">\n" +
    "      <input ng-hide=\"tasksFileUploader.isUploading || tasksFileUploader.queue.length == 0\" type=\"submit\" class=\"btn btn-primary form-control col-sm-2 col-sm-offset-3\" value=\"Import\" />\n" +
    "      <div class=\"col-sm-offset-3 col-sm-6\" ng-show=\"tasksFileUploader.isUploading\">\n" +
    "        <progressbar class=\"progress-striped active\" value=\"tasksFileUploader.progress\"></progressbar>\n" +
    "        <p class=\"help-block text-center\" ng-show=\"tasksFileUploader.progress == 100\">\n" +
    "          Please wait for the server to insert the tasks...\n" +
    "        </p>\n" +
    "      </div>\n" +
    "    </div>\n" +
    "  <form class=\"form-horizontal\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Download</label>\n" +
    "      <button ng-click=\"requestTasksExport()\" class=\"btn btn-primary form-control col-sm-2\">Export</button>\n" +
    "    </div>\n" +
    "  </form><!--/csv-batch-->\n" +
    "</div>");
}]);

angular.module("units/partials/templates/task-edit-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/task-edit-modal.tpl.html",
    "<div>\n" +
    "	<form class=\"form-horizontal\" ng-submit=\"saveTask()\" role=\"form\">\n" +
    "  	<div class=\"modal-header\">\n" +
    "  		<h3>{{isNew ? \"Create Task\" : \"Edit Task\"}}</h3>\n" +
    "  	</div>\n" +
    "  	<div class=\"modal-body\">\n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">Name</label>\n" +
    "        <input type=\"text\" class=\"form-control col-sm-8\" ng-model=\"task.name\">\n" +
    "      </div><!--/name-->\n" +
    "      \n" +
    "  	  <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\">Abbreviation</label>\n" +
    "        <input type=\"text\" class=\"form-control col-sm-8\" ng-model=\"task.abbr\"/>\n" +
    "  	  </div><!--/abbr-->\n" +
    "  	  \n" +
    "  	  <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\">Description</label>\n" +
    "        <textarea class=\"form-control col-sm-8\" ng-model=\"task.desc\"></textarea>\n" +
    "  	  </div><!--/desc-->\n" +
    "  	  \n" +
    "  	  <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\">Weighting</label>\n" +
    "        <input type=\"number\" class=\"form-control col-sm-8\" ng-model=\"task.weight\" min=\"1\"/>\n" +
    "  	  </div><!--/weighting-->\n" +
    "  	  \n" +
    "  	  <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\">Required</label>\n" +
    "        <input type=\"checkbox\" class=\"form-control col-sm-8\" ng-model=\"task.required\"/>\n" +
    "  	  </div><!--/required-->\n" +
    "  	  \n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">Target Date</label>\n" +
    "        <div class=\"col-sm-8 input-group\">\n" +
    "          <input datepicker-popup=\"yyyy-MM-dd\" is-open=\"opened\" type=\"text\" class=\"form-control\" ng-model=\"task.target_date\" placeholder=\"yyyy-MM-dd\" close-text=\"Close\" />\n" +
    "          <span class=\"input-group-btn\">\n" +
    "            <button class=\"btn btn-default\" ng-click=\"open($event)\"><i class=\"glyphicon glyphicon-calendar\"></i></button>\n" +
    "          </span>\n" +
    "        </div> \n" +
    "      </div><!--/target-date-->\n" +
    "\n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">File Uploads</label>\n" +
    "        <div class=\"col-sm-8 form-control-static\" ng-show=\"task.upload_requirements.length == 0\">\n" +
    "          None\n" +
    "        </div>\n" +
    "        <ul class=\"col-sm-8 input-group\" ng-show=\"task.upload_requirements.length > 0\">\n" +
    "          <li class=\"list-group-item\" ng-repeat=\"upreq in task.upload_requirements\">\n" +
    "            <input class=\"form-control\" placeholder=\"Upload Name\" type=\"text\" required ng-model=\"upreq.name\"/>\n" +
    "            <br/>\n" +
    "            <label name=\"upreq-type-{{upreq.key}}\" class=\"radio-inline\" for=\"upreq-type-{{upreq.key}}-code\">\n" +
    "              <input type=\"radio\" id=\"upreq-type-{{upreq.key}}-code\" value=\"code\" ng-model=\"upreq.type\"/>Code\n" +
    "            </label>\n" +
    "            <label name=\"upreq-type-{{upreq.key}}\" class=\"radio-inline\" for=\"upreq-type-{{upreq.key}}-document\">\n" +
    "              <input type=\"radio\" id=\"upreq-type-{{upreq.key}}-document\" value=\"document\" ng-model=\"upreq.type\"/>Document\n" +
    "            </label>\n" +
    "            <label name=\"upreq-type-{{upreq.key}}\" class=\"radio-inline\" for=\"upreq-type-{{upreq.key}}-image\">\n" +
    "              <input type=\"radio\" id=\"upreq-type-{{upreq.key}}-image\" value=\"image\" ng-model=\"upreq.type\"/>Image\n" +
    "            </label>\n" +
    "            <i class=\"glyphicon glyphicon-remove pull-right\" style=\"padding-top: 10px; cursor: pointer;\" ng-click=\"removeUpReq(upreq)\"></i>\n" +
    "          </li>\n" +
    "        </ul>\n" +
    "      </div>\n" +
    "      <div class=\"form-group\">\n" +
    "        <button type=\"button\" ng-click=\"addUpReq()\" class=\"btn btn-success col-sm-offset-10 col-sm-1\">\n" +
    "            <span class=\"glyphicon glyphicon-plus\"></span>\n" +
    "        </button>\n" +
    "      </div><!--/upload-requirements-->\n" +
    "\n" +
    "		<div class=\"modal-footer text-right\">\n" +
    "			<input type=\"submit\" class=\"btn btn-primary\" value=\"{{isNew ? 'Create' : 'Update'}}\" />\n" +
    "		</div>\n" +
    "	</form>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/partials/templates/tutor-unit-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/tutor-unit-context.tpl.html",
    "<div>\n" +
    "  <h2 class=\"pull-left\">{{unit.name}}</h2>\n" +
    "    \n" +
    "  <form role=\"search\" class=\"pull-right form-horizontal\">\n" +
    "      <input id=\"searchbar\" class=\"input-md form-control\" placeholder=\"Search students, tutors...\" type=\"search\" ng-model=\"search.$\" typeahead=\"student.name for student in students | filter:$viewValue | limitTo:8\" />\n" +
    "      <p class=\"help-block\" ng-show=\"filteredStudents.length < students.length && filteredStudents.length != 0\">Showing {{filteredStudents.length}} of {{students.length}} students enrolled.</p>\n" +
    "      <p class=\"help-block\" ng-show=\"filteredStudents.length < students.length && filteredStudents.length == 0\">No students found.</p>\n" +
    "  </form>\n" +
    "    \n" +
    "	<div class=\"table-responsive\">\n" +
    "	    <table class=\"table table-condensed table-hover\">\n" +
    "	    	<thead>\n" +
    "	    		<tr>\n" +
    "		    		<th><a href=\"\" ng-click=\"sortOrder='student_id'; reverse=!reverse\">Student ID</a></th>\n" +
    "		    		<th><a href=\"\" ng-click=\"sortOrder='name'; reverse=!reverse\">Name</a></th>\n" +
    "		    		<th>Stats</th>\n" +
    "		    		<th><a href=\"\" ng-click=\"sortOrder='tutorial.meeting_day'; reverse=!reverse\">Tutorial</a></th>\n" +
    "		    		<th>Actions</th>\n" +
    "		    	</tr>\n" +
    "	    	</thead>\n" +
    "	    	<tbody>\n" +
    "		    	<tr class=\"task-progress-row\" ng-repeat=\"student in filteredStudents = (students | filter:search) | orderBy:sortOrder:reverse | startFrom:(currentPage - 1) * pageSize | limitTo: pageSize\" >\n" +
    "			    	<td class=\"task-progress\" ng-click=\"student.open = !student.open\"><a href=\"#/projects/{{student.project_id}}?unitRole={{assessingUnitRole.id}}\">{{student.student_id}}</a></td>\n" +
    "            		<td ng-click=\"student.open = !student.open\">{{student.name}}</td>\n" +
    "			    	<td ng-click=\"student.open = !student.open\" class=\"task-progress-bar\">\n" +
    "			    		<accordion ng-if=\"accordionReady\" class=\"task-progress-accordion\" ng-click=\"student.open = !student.open\">\n" +
    "	    					<accordion-group is-open=\"student.open\">\n" +
    "	    						<accordion-heading>\n" +
    "	    							<progress class=\"task-progress\" animate=\"false\">\n" +
    "	    								<bar ng-repeat=\"bar in student.task_stats | filter:barLargerZero track by $index\" value=\"bar.value\" type=\"{{bar.type}}\">\n" +
    "	    									<span ng-hide=\"bar.value < 10\">{{bar.value}}%</span>\n" +
    "	    								</bar>\n" +
    "	    							</progress>\n" +
    "	    						</accordion-heading>\n" +
    "	    						<div ng-style=\"{ 'min-height': '{{accordionHeight}}px' }\" >\n" +
    "      								<student-unit-tasks ng-if=\"student.open\" student=\"student\" student-project-id=\"student.project_id\" task-def=\"taskDef\" unit=\"unit\" assessing-unit-role=\"assessingUnitRole\" project=\"student.project\"></student-unit-tasks>\n" +
    "	      						</div>\n" +
    "	    					</accordion-group>\n" +
    "						</accordion>\n" +
    "					</td>\n" +
    "			    	<td ng-click=\"student.open = !student.open\"> <span tooltip-html-unsafe=\"<strong>{{student.tutorial.meeting_day}} {{student.tutorial.meeting_time | date: 'shortTime'}}</strong><br/> {{student.tutorial.meeting_location}} - {{student.tutorial.tutor.name}}\"> {{student.tutorial.abbreviation}} </span></td>\n" +
    "			    	<td><button type=\"button\" class=\"btn btn-info\" ng-click=\"transitionWeekEnd(student)\">Discussed</button></td>\n" +
    "			    </tr>\n" +
    "		    </tbody>\n" +
    "		</table>\n" +
    "		<a href class=\"btn btn-success pull-right\" ng-click=\"showEnrolModal()\">Enrol Student</a>\n" +
    "		<pagination total-items=\"filteredStudents.length\" ng-model=\"currentPage\" items-per-page=\"pageSize\" max-size=\"maxSize\" class=\"pagination-sm pull-left\" boundary-links=\"true\" rotate=\"false\"></pagination>\n" +
    "	</div>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/partials/templates/tutorial-admin-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/tutorial-admin-context.tpl.html",
    "<div>\n" +
    "  <table class=\"table table-condensed table-hover\">\n" +
    "    <thead>\n" +
    "      <tr> \n" +
    "        <th>Abbr</th>\n" +
    "        <th>Location</th>\n" +
    "        <th>Day</th>\n" +
    "        <th>Time</th>\n" +
    "        <th>Tutor</th>\n" +
    "      </tr>\n" +
    "    </thead>\n" +
    "    <tbody>\n" +
    "      <tr ng-repeat=\"tutorial in unit.tutorials\" ng-click=\"editTutorial(tutorial)\">\n" +
    "        <td>{{tutorial.abbreviation}}</td>\n" +
    "        <td>{{tutorial.meeting_location}}</td>\n" +
    "        <td>{{tutorial.meeting_day}}</td>\n" +
    "        <td>{{tutorial.meeting_time | date:'HH:mm'}}</td>\n" +
    "        <td>{{tutorial.tutor_name}}</td>\n" +
    "      </tr>\n" +
    "    </tbody>\n" +
    "  </table>\n" +
    "  <button class=\"btn btn-primary pull-right\" ng-click=\"createTutorial()\">Create Tutorial</button>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/partials/templates/tutorial-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/tutorial-modal.tpl.html",
    "\n" +
    "<div>\n" +
    "	<form class=\"form-horizontal\" ng-submit=\"saveTutorial()\" role=\"form\">\n" +
    "  	<div class=\"modal-header\">\n" +
    "  		<h3>{{isNew ? \"Create Tutorial\" : \"Edit Tutorial\"}}</h3>\n" +
    "  	</div>\n" +
    "  	<div class=\"modal-body\">\n" +
    "  	  <div class=\"form-group\" required>\n" +
    "  	    <label class=\"col-sm-3 control-label\">Abbreviation</label>\n" +
    "        <input type=\"text\" class=\"form-control col-sm-7\"\n" +
    "        ng-model=\"tutorial.abbreviation\"/>\n" +
    "  	  </div>\n" +
    "      <div class=\"form-group\" required>\n" +
    "        <label class=\"col-sm-3 control-label\">Location</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" \n" +
    "        ng-model=\"tutorial.meeting_location\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" required>\n" +
    "        <label class=\"col-sm-3 control-label\">Day</label>\n" +
    "        <select id=\"day\" class=\"form-control col-sm-7\" ng-model=\"tutorial.meeting_day\" name=\"day\">\n" +
    "          <option value=\"Monday\">Monday</option>\n" +
    "          <option value=\"Tuesday\">Tuesday</option>\n" +
    "          <option value=\"Wednesday\">Wednesday</option>\n" +
    "          <option value=\"Thursday\">Thursday</option>\n" +
    "          <option value=\"Friday\">Friday</option>\n" +
    "        </select>\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" required>\n" +
    "        <label class=\"col-sm-3 control-label\">Time</label>\n" +
    "        <timepicker ng-model=\"tutorial.meeting_time\" hour-step=\"1\"\n" +
    "        minute-step=\"30\" show-meridian=\"false\"></timepicker>\n" +
    "      </div>\n" +
    "      <div class=\"form-group\">\n" +
    "        <label class=\"col-sm-3 control-label\">Tutor</label>\n" +
    "        <input type=\"text\" class=\"form-control col-sm-7\" ng-model=\"tutorial.tutor\" typeahead=\"tutor as tutor.name for tutor in tutors | filter: $viewValue\">\n" +
    "      </div>\n" +
    "  	</div>\n" +
    "		<div class=\"modal-footer text-right\">\n" +
    "			<input type=\"submit\" class=\"btn btn-primary\" value=\"{{isNew ? 'Create' : 'Update'}}\" />\n" +
    "		</div>\n" +
    "	</form>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/partials/templates/unit-admin-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/unit-admin-context.tpl.html",
    "<form class=\"form-horizontal row\" role=\"form\" ng-submit=\"saveUnit()\">\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"code\">Code</label>\n" +
    "    <input class=\"form-control col-sm-9\" id=\"code\" type=\"text\" placeholder=\"Enter unit code\" ng-model=\"unit.code\">\n" +
    "  </div><!--/code-date-->\n" +
    "\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"name\">Name</label>\n" +
    "    <input id=\"name\" type=\"text\" class=\"form-control col-sm-9\" ng-model=\"unit.name\">\n" +
    "  </div><!--/name-date-->\n" +
    "  \n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"description\">Description</label>\n" +
    "    <textarea id=\"description\" class=\"form-control col-sm-9\" ng-model=\"unit.description\"></textarea>\n" +
    "  </div><!--/description-date-->\n" +
    "\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"startdate\">Start Date</label>\n" +
    "    <div class=\"col-sm-9 input-group\">\n" +
    "      <input type=\"text\" class=\"form-control\" id=\"startdate\" datepicker-popup=\"{{format}}\" ng-model=\"unit.start_date\"   is-open=\"startOpened\" ng-required=\"true\" close-text=\"Close\" />\n" +
    "      <span class=\"input-group-btn\">\n" +
    "        <button class=\"btn btn-default\" ng-click=\"open($event,'start')\"><i class=\"glyphicon glyphicon-calendar\"></i></button>\n" +
    "      </span>\n" +
    "    </div>\n" +
    "  </div><!--/start-date-->\n" +
    "\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"enddate\">End Date</label>\n" +
    "    <div class=\"col-sm-9 input-group\">\n" +
    "      <input datepicker-popup=\"{{format}}\" id=\"enddate\" type=\"text\" class=\"form-control\" ng-model=\"unit.end_date\" is-open=\"endOpened\"ng-required=\"true\" close-text=\"Close\" />\n" +
    "      <span class=\"input-group-btn\">\n" +
    "        <button class=\"btn btn-default\" ng-click=\"open($event,'end')\"><i class=\"glyphicon glyphicon-calendar\"></i></button>\n" +
    "      </span>\n" +
    "    </div> \n" +
    "  </div><!--/end-date-->\n" +
    "\n" +
    "  <div class=\"form-group\">\n" +
    "    <label class=\"col-sm-2 control-label\" for=\"enddate\">Active</label>\n" +
    "    <div class=\"col-sm-9 input-group\">\n" +
    "      <span ng-click=\"unit.active=!unit.active\" ng-show=\"unit.active\" class=\"glyphicon glyphicon-ok text-success\"></span>\n" +
    "      <span ng-click=\"unit.active=!unit.active\" ng-hide=\"unit.active\" class=\"glyphicon glyphicon-remove text-danger\"></span>\n" +
    "    </div> \n" +
    "  </div><!--/end-date-->\n" +
    "  \n" +
    "  <div class=\"form-group\">\n" +
    "    <input type=\"submit\" value=\"{{ unit.id == -1 ? 'Create Unit' : 'Update Unit' }}\" class=\"btn btn-primary col-sm-2 col-sm-offset-9\" />\n" +
    "  </div>\n" +
    "  <br />\n" +
    "</form>");
}]);

angular.module("units/partials/templates/unit-create-modal.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/partials/templates/unit-create-modal.tpl.html",
    "<div>\n" +
    "  	<div class=\"modal-header\">\n" +
    "  		<h3>Create Unit</h3>\n" +
    "  	</div>\n" +
    "  	<div class=\"modal-body\">\n" +
    "      <admin-unit-context unit=\"unit\"></admin-unit-context>\n" +
    "  	</div>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/show.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/show.tpl.html",
    "<div ng-switch on=\"unitRole.role\">\n" +
    "	<ul class=\"breadcrumb\">\n" +
    "    	<li><a href=\"#/home\">Units</a></li>\n" +
    "    	<li class=\"active\">{{unitRole.unit_name}} {{unitRole.role.name}}</li>\n" +
    "	</ul>\n" +
    "\n" +
    "	<div class=\"col-md-offset-2 col-md-8\" ng-switch on=\"unitRole.role\">\n" +
    "		<tutor-unit-context ng-switch-when=\"Tutor\"></tutor-unit-context>\n" +
    "		<tutor-unit-context ng-switch-when=\"Convenor\"></tutor-unit-context>\n" +
    "		<!-- <student-unit-context student-project-id=\"unitRole.project_id\" task-def=\"taskDef\" unit=\"unit\" ng-switch-when=\"Student\"></student-unit-context> -->\n" +
    "	</div>\n" +
    "</div>\n" +
    "");
}]);

angular.module("units/unit.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("units/unit.tpl.html",
    "<div class=\"col-md-offset-2 col-md-8\">\n" +
    "  <div ng-hide=\"unit.id == -1\">\n" +
    "    <h3>Edit {{unit.name}}</h3>\n" +
    "  </div>\n" +
    "  <div ng-show=\"unit.id == -1\">\n" +
    "    <h3>Create Unit</h3>\n" +
    "  </div>\n" +
    "  <tabset>\n" +
    "    <tab heading=\"Unit\">\n" +
    "      <admin-unit-context unit=\"unit\"></admin-unit-context>\n" +
    "    </tab>\n" +
    "    <tab heading=\"Staff\">\n" +
    "      <staff-admin-unit-context></convenor-admin-unit-context>\n" +
    "    </tab>\n" +
    "    <tab heading=\"Tutorials\"> \n" +
    "      <tutorial-unit-context></tutorial-unit-context>\n" +
    "    </tab>\n" +
    "    <tab heading=\"Student Enrolments\">\n" +
    "      <enrol-students-context></enrol-students-context>\n" +
    "    </tab>\n" +
    "    <tab heading=\"Tasks\">\n" +
    "      <task-admin-unit-context></task-admin-unit-context>\n" +
    "    </tab>\n" +
    "  </tabset>\n" +
    "</div>\n" +
    "");
}]);

angular.module("users/admin.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("users/admin.tpl.html",
    "<ul class=\"breadcrumb\">\n" +
    "  	<li><a href=\"#/home\">Home</a></li>\n" +
    "  	<li>Administrator</li>\n" +
    "  	<li class=\"active\">Manage Users</li>\n" +
    "</ul>\n" +
    "<div class=\"col-md-offset-2 col-md-8\">\n" +
    "  <h2>Manage Doubtfire Users</h2>\n" +
    "  <tabset>\n" +
    "    <tab heading=\"User List\">\n" +
    "      <user-list-context></user-list-context>\n" +
    "    </tab>\n" +
    "    <tab heading=\"Import / Export\">\n" +
    "      <data-import-export-context></data-import-export-context>\n" +
    "    </tab>\n" +
    "  </tabset>\n" +
    "</div>\n" +
    "");
}]);

angular.module("users/partials/templates/import-export-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("users/partials/templates/import-export-context.tpl.html",
    "<div>\n" +
    "  <form class=\"form-horizontal\" ng-submit=\"submitUpload()\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Upload</label>\n" +
    "      <input ng-hide=\"fileUploader.isHTML5\" type=\"file\" class=\"col-sm-7\" accept=\"text/csv\" uploader=\"fileUploader\" ng-required=\"!fileUploader.isHTML5\" nv-file-select />\n" +
    "      <div nv-file-drop ng-show=\"fileUploader.isHTML5 && fileUploader.queue.length == 0\" class=\"drop well col-sm-7\" nv-file-over uploader=\"fileUploader\">\n" +
    "        <p class=\"fa fa-file-excel-o fa-3x\"></p>\n" +
    "        <br/>\n" +
    "        Drop CSV here\n" +
    "      </div>\n" +
    "	    <p ng-show=\"fileUploader.queue.length == 1\" class=\"form-control-static\">{{fileUploader.queue[0].file.name}} <span class=\"glyphicon glyphicon-file\"></span></p>\n" +
    "    </div>\n" +
    "    <div class=\"form-group\">\n" +
    "      <input ng-hide=\"fileUploader.isUploading || fileUploader.queue.length == 0\" type=\"submit\" class=\"btn btn-primary form-control col-sm-2 col-sm-offset-3\" value=\"Import\" />\n" +
    "      <div class=\"col-sm-offset-3 col-sm-6\" ng-show=\"fileUploader.isUploading\">\n" +
    "        <progressbar class=\"progress-striped active\" value=\"fileUploader.progress\"></progressbar>\n" +
    "        <p class=\"help-block text-center\" ng-show=\"fileUploader.progress == 100\">\n" +
    "          Please wait for the server to insert the users...\n" +
    "        </p>\n" +
    "      </div>\n" +
    "    </div>\n" +
    "  <form class=\"form-horizontal\">\n" +
    "    <div class=\"form-group\">\n" +
    "      <label class=\"col-sm-3 control-label\">Download</label>\n" +
    "      <input ng-click=\"requestExport()\" type=\"submit\" class=\"btn btn-primary form-control col-sm-2\" value=\"Export\" />\n" +
    "    </div>\n" +
    "  </form>\n" +
    "</div>");
}]);

angular.module("users/partials/templates/user-list-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("users/partials/templates/user-list-context.tpl.html",
    "<form role=\"search\" class=\"pull-right form-horizontal\">\n" +
    "  <input id=\"searchbar\" class=\"input-md form-control\" placeholder=\"Search for users...\" type=\"search\" ng-model=\"search.$\" typeahead=\"user.name for user in users | filter:$viewValue | limitTo:8\" />\n" +
    "  <p class=\"help-block\" ng-show=\"filteredUsers.length < students.length && filteredUsers.length != 0\">Showing {{filteredUsers.length}} of {{users.length}} users.</p>\n" +
    "  <p class=\"help-block\" ng-show=\"filteredUsers.length < students.length && filteredUsers.length == 0\">No students found.</p>\n" +
    "</form>\n" +
    "<div class=\"table-responsive\">\n" +
    "  <table class=\"table table-condensed table-hover\">\n" +
    "  	<thead>\n" +
    "  		<tr>\n" +
    "    		<th><a href=\"\" ng-click=\"sortOrder='id'; reverse=!reverse\">User ID</a></th>\n" +
    "    		<th><a href=\"\" ng-click=\"sortOrder='first_name'; reverse=!reverse\">First Name</a></th>\n" +
    "    		<th><a href=\"\" ng-click=\"sortOrder='last_name'; reverse=!reverse\">Last Name</a></th>\n" +
    "    		<th>Username</th>\n" +
    "    		<th>Email</th>\n" +
    "    		<th><a href=\"\" ng-click=\"sortOrder='system_role'; reverse=!reverse\">System Role</a></th>\n" +
    "    		<th>Active</th>\n" +
    "    	</tr>\n" +
    "  	</thead>\n" +
    "  	<tbody>\n" +
    "  	  <tr ng-repeat=\"user in filteredUsers = (users | filter:search) | orderBy:sortOrder:reverse | startFrom:(currentPage - 1) * pageSize | limitTo: pageSize\" ng-click=\"showUserModal(user)\">\n" +
    "  	    <td>{{user.id}}</td>\n" +
    "  	    <td>{{user.first_name}}</td>\n" +
    "  	    <td>{{user.last_name}}</td>\n" +
    "  	    <td>{{user.username}}</td>\n" +
    "  	    <td><a href=\"mailto:{{user.email}}\">{{user.email}}</a></td>\n" +
    "  	    <td>\n" +
    "  	      {{user.system_role}}\n" +
    "        </td>\n" +
    "  	    <td>\n" +
    "  	      <!-- TODO: Add active state once implemented in API \n" +
    "  	                (implement ng-show and ng-hide for the spans below)-->\n" +
    "  	                N/A\n" +
    "  	      <span ng-show=\"false\" class=\"glyphicon glyphicon-ok text-success\"></span>\n" +
    "  	      <span ng-hide=\"true\" class=\"glyphicon glyphicon-remove text-danger\"></span>\n" +
    "  	    </td>\n" +
    "  	  </tr>\n" +
    "  	</tbody>\n" +
    "  </table><a href class=\"btn btn-success pull-right\" ng-click=\"showUserModal()\">Add New User</a>\n" +
    "  <pagination total-items=\"filteredUsers.length\" ng-model=\"currentPage\" items-per-page=\"pageSize\" max-size=\"maxSize\" class=\"pagination-sm pull-left\" boundary-links=\"true\" rotate=\"false\"></pagination>\n" +
    "</div>");
}]);

angular.module("users/partials/templates/user-modal-context.tpl.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("users/partials/templates/user-modal-context.tpl.html",
    "<div>\n" +
    "	<form class=\"form-horizontal\" ng-submit=\"saveUser()\" role=\"form\">\n" +
    "  	<div class=\"modal-header\">\n" +
    "  		<h3>{{isNew ? \"Create User\" : \"Edit User\"}}</h3>\n" +
    "  	</div>\n" +
    "  	<div class=\"modal-body\">\n" +
    "  	  <div class=\"form-group\" ng-if=\"!isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\">Username</label>\n" +
    "  	    <p class=\"form-control-static\">{{user.username}}</p>\n" +
    "  	  </div>\n" +
    "  	  <div class=\"form-group\" ng-if=\"isNew\">\n" +
    "  	    <label class=\"col-sm-3 control-label\" ng-required=\"isNew\">Username</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" placeholder=\"1744070\" ng-model=\"user.username\">\n" +
    "  	  </div>\n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">First Name</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" placeholder=\"Fred\" ng-model=\"user.first_name\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">Last Name</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" placeholder=\"Derf\" ng-model=\"user.last_name\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">Email</label>\n" +
    "        <input type=\"email\" class=\"form-control col-sm-7\" placeholder=\"fred@doubtfire.org\" ng-model=\"user.email\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\">\n" +
    "        <label class=\"col-sm-3 control-label\">Nickname</label>\n" +
    "        <input type=\"input\" class=\"form-control col-sm-7\" placeholder=\"Freddy McDerfson\" ng-model=\"user.nickname\">\n" +
    "      </div>\n" +
    "      <div class=\"form-group\" if-role=\"Admin Convenor\" ng-required=\"isNew\">\n" +
    "        <label class=\"col-sm-3 control-label\">System Role</label>\n" +
    "        <label class=\"radio-inline\" if-role=\"Admin\">\n" +
    "          <input type=\"radio\" ng-disabled=\"user.id == currentUser.id\" name=\"sysRole\" if-role=\"Admin\" ng-model=\"user.system_role\" value=\"Admin\">Administrator\n" +
    "        </label>\n" +
    "        <label class=\"radio-inline\">\n" +
    "          <input type=\"radio\" ng-disabled=\"user.id == currentUser.id\" name=\"sysRole\" if-role=\"Admin Convenor\" ng-model=\"user.system_role\" value=\"Convenor\">Convenor\n" +
    "        </label>\n" +
    "        <label class=\"radio-inline\">\n" +
    "          <input type=\"radio\" ng-disabled=\"user.id == currentUser.id\" name=\"sysRole\" if-role=\"Admin Convenor\" ng-model=\"user.system_role\" value=\"Tutor\">Tutor\n" +
    "        </label>\n" +
    "        <label class=\"radio-inline\">\n" +
    "          <input type=\"radio\" ng-disabled=\"user.id == currentUser.id\" name=\"sysRole\" if-role=\"Admin Convenor\" ng-model=\"user.system_role\" value=\"Student\">Student\n" +
    "        </label>\n" +
    "        <p ng-show=\"user.id == currentUser.id\" class=\"help-block text-center\">You cannot modify your own permissions</p>\n" +
    "      </div>\n" +
    "  	</div>\n" +
    "		<div class=\"modal-footer text-right\">\n" +
    "			<input type=\"submit\" class=\"btn btn-primary\" value=\"{{isNew ? 'Add' : 'Save'}}\" />\n" +
    "		</div>\n" +
    "	</form>\n" +
    "</div>");
}]);
