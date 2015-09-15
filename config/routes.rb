Rails.application.routes.draw do
  get '/irish_census/counties', to: 'irish_census/counties#index'
  get '/irish_census/counties/:id', to: 'irish_census/counties#show', as: 'neo_county'
  get '/irish_census/deds/:id', to: 'irish_census/deds#show', as: 'neo_ded'
  get '/irish_census/townland_streets/:id', to: 'irish_census/townland_streets#show', as: 'neo_townland_street'
  get '/irish_census/houses/:id', to: 'irish_census/houses#show', as: 'neo_house'

  get '/irish_census/residents/:id', to: 'irish_census/residents#show', as: 'irish_census_resident'
  get '/irish_census/houses/:id', to: 'irish_census/houses#show', as: 'irish_census_house'
  get '/irish_census/houses_by_census/:census_id', to: 'irish_census/houses#show', as: 'irish_census_house_by_census_id'

  get '/irish_census/compare_candidate_houses_by_census/:census_id', to: 'irish_census/houses#compare_candidate_houses'

  get '/irish_census/houses/compare/:census_id_1/:census_id_2', to: 'irish_census/houses#compare'

  get '/irish_census/redirect_from_census_website', to: 'irish_census/main#redirect_from_census_website'

  put '/irish_census/residents/identify', to: 'irish_census/residents#identify'

  root 'irish_census/counties#index'
end
