require 'grape'
require 'entities_v2'

require_relative 'helpers/session_helpers'
require_relative 'helpers/paging_helpers'
require_relative 'helpers/product_helpers'

module V2
  class GithubApiV2 < Grape::API
    
    helpers SessionHelpers
    helpers PagingHelpers
    helpers ProductHelpers

    resource :github do
      before do
        track_apikey
      end

      #-- GET '/' -------------------------------------------------------------
      desc "lists your's github repos", {
        notes: %q[
          It shows all repositories you and your's organization have hosted on Github.

          This enpoint expects that you have github account already connected and tokens
          are still valid. If not, then please visit **settings page**.
          to update your github credentials.

          **PS** If it's shows old data, then you can use `github/sync` endpoint
          to import the latest changes.
        ]
      }
      params do
        optional :lang, type: String, desc: "Filter by language"
        optional :private, type: Boolean, desc: "Filter by visibility"
        optional :org_name, type: String, desc: "Filter by name of organization"
        optional :org_type, type: String, desc: "Filter by type of organization"
        optional :page, type: String, default: '1', desc: "Number of page"
      end
      get '/' do
        authorized?
        user = current_user
        if !user.github_account_connected?
          error! "Github account is not connected. Check your settings on versioneye.com", 401
        end

        page = params[:page].to_i
        query_filters = {}
        query_filters[:language] = params[:lang] unless params[:lang].nil?
        query_filters[:private] = params[:private] unless params[:private].nil?
        query_filters[:owner_login] = params[:org_name] unless params[:org_name].nil?
        query_filters[:owner_type] = params[:org_type] unless params[:org_type].nil?

        p query_filters

        if user.github_repos.all.count == 0
          #try to import users repos when there's no repos.
          GitHubService.cached_user_repos(user)
        end

        repos = user.github_repos.where(query_filters).paginate(per_page: 30, page: page)
        repos.each do |repo|
          repo[:repo_key] = encode_prod_key(repo[:fullname])
        end
        paging = make_paging_object(repos)

        present :repos,  repos, with: EntitiesV2::RepoEntity
        present :paging, paging, with: EntitiesV2::PagingEntity
      end


      #-- GET '/:repo_key' ----------------------------------------------------
      desc "shows the detailed information for the repository", {
        notes: %q[
          Due the limits of our current API framework, the repo key has to be
          encoded as url-safe string. That means all '/' has to be replaced with
          colons ':' and '.' has to be replaced with '~'.

          For example,  repository with fullname `versioneye/veye` has to transformed
          to `versioneye:veye`.
        ]
      }
      params do
        requires :repo_key, type: String, desc: "encoded repo name with optional branch info."
      end
      get '/:repo_key' do
        authorized?
        user = current_user
        repo_fullname = decode_prod_key(params[:repo_key])

        repo = user.github_repos.by_fullname(repo_fullname).first
        repo_projects = Project.by_user(user).by_github(repo_fullname).to_a
        unless repo
          repo = {}
        end
        present :repo, repo, with: EntitiesV2::RepoEntity
        present :imported_projects, repo_projects, with: EntitiesV2::ProjectEntity
      end

      #-- POST '/:repo_key' --------------------------------------------------
      desc "imports project file from github", {
        notes: %q[
          You can use this API to import your github repo as project.

          Due the limits of our current API framework, the repo key has to be
          encoded as url-safe string. That means all '/' has to be replaced with
          colons ':' and '.' has to be replaced with '~'.

          For example,  repository with fullname `versioneye/veye` has to transformed
          to `versioneye:veye`.
        ]
      }
      params do
        requires :repo_key, type: String, desc: "encoded repo name with optional branch info"
        optional :branch, type: String, default: "master", desc: "the name of branch"
      end
      post '/:repo_key' do
        authorized?
        user = current_user
        repo_name = decode_prod_key(params[:repo_key])
        branch = params[:branch]

        repo = user.github_repos.by_fullname(repo_name).first
        ProjectService.import_from_github(user, repo_name, branch)
        project = Project.by_user(current_user).by_github(repo_name).where(github_branch: branch).first

        present :repo, repo, with: EntitiesV2::RepoEntity
        present :project, project, with: EntitiesV2::ProjectEntity
      end

      #-- DELETE '/:repo_key' -------------------------------------------------
      desc "remove imported project", {
        notes: %q[
          Due the limits of our current API framework, the repo key has to be
          encoded as url-safe string. That means all '/' has to be replaced with
          colons ':' and '.' has to be replaced with '~'.

          For example,  repository with fullname `versioneye/veye` has to transformed
          to `versioneye:veye`.
        ]
      }
      params do
        requires :repo_key, type: String, desc: "encoded repo-key with optional brnach info"
        optional :branch, type: String, default: "master", desc: "to specify branch"
      end
      delete '/:repo_key' do
        authorized?
        user = current_user
        repo_name = decode_prod_key(params[:repo_key])
        branch = params[:branch]

        project = Project.by_user(user).by_github(repo_name).where(github_branch: branch).shift
        error!("Project doesnt exists", 400) if project.nil?
        ProjectService.destroy project[:_id].to_s
        present :success, true
      end

      #TODO: add sync to update data

      #todo: search on github
    end #end of resource block
  end
end

