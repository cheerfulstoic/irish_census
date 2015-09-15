# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
  put_result = (e, type) ->
    e.preventDefault()

    console.log {target: e.target}

    target = $(e.target)
    if target.data('same-identity')
      console.log 'same-identity'
      return false
    else
      source_id = target.data('source-id')
      target_id = target.data('target-id')
      same_link = $(e.target).parent().find('a.same-resident')
      $.ajax '/irish_census/residents/identify', type: 'PUT', data: {type, source_id, target_id}
        .success (result) ->
          console.log {result}
          if result.same_identity
            same_link.addClass 'disabled'
            same_link.data 'same-identity', true
          else
            same_link.removeClass 'disabled'
            same_link.data 'same-identity', false


  console.log 'hi'

  $('a.same-resident').click (e) -> put_result e, 'same'
  $('a.clear-resident').click (e) -> put_result e, 'clear'

  $('#compare').click (e) ->
    window.open "/irish_census/houses/compare/#{$('#compare').data('house-id')}/#{$('#compare-input').val()}"
