function toggle_submit_button(){return console.debug("user toggled lottery button"),$(".lottery-btn.active").length>=2?(console.log("Showing submit button"),$(".lottery-submit-btn").removeClass("hide")):$(".lottery-submit-btn").addClass("hide"),!1}$(document).ready(function(){$(".btn-group").button(),$(".lottery-btn").on("click",function(t){toggle_submit_button()})});