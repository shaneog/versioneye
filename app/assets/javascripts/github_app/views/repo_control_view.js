define([
        'underscore', 'backbone',
        '/assets/github_app/views/repo_control_item_view'],
  function(_, Backbone, GithubRepoControlItemView){

    _.templateSettings = {
      interpolate: /\{\{\=(.+?)\}\}/g,
         evaluate: /\{\{(.+?)\}\}/g
    };

    var GithubRepoControlView = Backbone.View.extend({
      tagName: "table",
      className: "github-repo-control table table-striped row-fluid",
      render: function(){
        var project_branches = this.model.get('branches') || [];
        var project_files = this.model.get('project_files') || [];
        _.each(project_branches, function(branch){
          var branch_files = project_files[branch] || [];
          var item_view = new GithubRepoControlItemView({
            model: this.model,
            branch: branch,
            project_files: branch_files
          });
          this.$el.append(item_view.render().$el);

        }, this);

        return this;
      }
    });

    return GithubRepoControlView;
  });
