house_ids = ["ab8c0176-59b4-4873-b253-ac56495869da", "6a0cfc17-5c30-4054-b7c0-a2d4632ecd92", "602b0e4b-a5df-49f3-9030-34acdbb1709a", "84337271-49b8-44bc-96f3-268ba4ec5c95", "830395e7-f7cf-4ced-9837-31c25a141c13"]

Neo::House.where(id: house_ids).residents.each do |resident|
  r = Neo::Resident.find(resident.id)
  r.refresh_similarity_candidate_rels
end

Neo::House.where(id: house_ids).residents.each do |resident|
  r = Neo::Resident.find(resident.id)
  r.add_relationships_similarity_candidate_scores
end
