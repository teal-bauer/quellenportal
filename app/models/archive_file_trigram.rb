# == Schema Information
#
# Table name: archive_file_trigrams
#
#  archive_file_trigrams :
#  call_number           :
#  origin_names          :
#  parents               :
#  rank                  :
#  summary               :
#  title                 :
#  archive_file_id       :
#  archive_node_id       :
#
class ArchiveFileTrigram < ApplicationRecord
  belongs_to :archive_file

  scope :search,
        ->(query) do
          return none if query.blank?

          where(archive_file_trigrams: sanitize_fts5(query)).order(:call_number)
        end

  def self.sanitize_fts5(query)
    operators = %w[AND OR NOT]
    tokens = query.scan(/"[^"]*"|\S+/)

    result = []
    tokens.each do |token|
      if operators.include?(token.upcase)
        # Only keep operator if it's between two terms
        result << token.upcase if result.last && !operators.include?(result.last)
      elsif token.start_with?('"') && token.end_with?('"') && token.length > 1
        result << token
      else
        prefix = ""
        word = token
        if word.start_with?("-")
          prefix = "-"
          word = word[1..]
        end
        suffix = word.end_with?("*") ? "*" : ""
        word = word.chomp("*")
        next if word.empty?
        result << prefix + '"' + word.gsub('"', '""') + '"' + suffix
      end
    end

    # Drop trailing operator
    result.pop if result.last && operators.include?(result.last)
    result.join(" ")
  end

  scope :in_node,
        ->(node_id) do
          return all if node_id.blank?

          node = ArchiveNode.find_by(id: node_id)
          return none unless node

          node_ids = [node.id] + node.descendant_ids
          where(archive_node_id: node_ids)
        end

  scope :lookup_by_call_number,
        ->(call_number) do
          where(archive_file_trigrams: "call_number: \"#{query}\"").order(
            :call_number
          )
        end
end
