index = Neo::Resident.searchkick_index
index.clean_indices
sub_index = index.create_index

Neo::DED.all.each do |ded|
  scope = ded.residents

  sub_index.import_scope(scope)
end

# Make sure to run this afterward!!!
index.swap(sub_index.name)
index.clean_indices
sub_index.refresh










# Test query:
# Neo::Resident.search('Annie').size