# == Schema Information
#
# Table name: originations
#
#  archive_file_id :string           not null
#  origin_id       :bigint           not null
#
# Indexes
#
#  index_originations_on_archive_file_id_and_origin_id  (archive_file_id,origin_id) UNIQUE
#
class Origination < ApplicationRecord
  belongs_to :archive_file
  belongs_to :origin
end
