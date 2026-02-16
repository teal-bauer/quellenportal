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

    # Merge short tokens (< 3 chars) with their next neighbor into a single
    # phrase so the trigram tokenizer can match them (e.g. "DK 107/11126").
    tokens = merge_short_tokens(tokens, operators)

    result = []
    tokens.each do |token|
      if operators.include?(token.upcase)
        # Only keep operator if it's between two terms
        result << token.upcase if result.last && !operators.include?(result.last)
      elsif token.start_with?('"') && token.end_with?('"') && token.length > 1
        result << token
      else
        negate = false
        word = token
        if word.start_with?("-")
          negate = true
          word = word[1..]
        end
        suffix = word.end_with?("*") ? "*" : ""
        word = word.chomp("*")
        next if word.empty?
        quoted = '"' + word.gsub('"', '""') + '"' + suffix
        if negate && result.last && !operators.include?(result.last)
          result << "NOT"
        end
        result << quoted
      end
    end

    # Drop trailing operator
    result.pop if result.last && operators.include?(result.last)
    result.join(" ")
  end

  def self.merge_short_tokens(tokens, operators)
    merged = []
    skip_next = false

    tokens.each_with_index do |token, i|
      if skip_next
        skip_next = false
        next
      end

      bare = token.delete_prefix("-").chomp("*")
      is_plain = !operators.include?(token.upcase) &&
        !token.start_with?('"') &&
        !token.start_with?("-")
      next_token = tokens[i + 1]
      next_plain = next_token &&
        !operators.include?(next_token.upcase) &&
        !next_token.start_with?('"') &&
        !next_token.start_with?("-")

      if is_plain && bare.length < 3 && next_plain
        merged << "#{token} #{next_token}"
        skip_next = true
      else
        merged << token
      end
    end

    merged
  end

  scope :in_node,
        ->(node_id) do
          return all if node_id.blank?

          node = ArchiveNode.find_by(id: node_id)
          return none unless node

          node_ids = [node.id] + node.descendant_ids
          where(archive_node_id: node_ids)
        end

  scope :in_date_range,
        ->(from, to) do
          return all if from.blank? || to.blank?

          where(
            "archive_file_id IN (SELECT id FROM archive_files " \
              "WHERE source_date_start >= ? AND source_date_start < ?)",
            from,
            to
          )
        end

  scope :lookup_by_call_number,
        ->(call_number) do
          where(archive_file_trigrams: "call_number: \"#{query}\"").order(
            :call_number
          )
        end

  def self.fonds_facets(query, node_id: nil, date_from: nil, date_to: nil)
    conditions = []
    binds = []

    if query.present?
      conditions << "archive_file_trigrams MATCH ?"
      binds << sanitize_fts5(query)
    end

    if node_id.present?
      node = ArchiveNode.find_by(id: node_id)
      if node
        ids = [node.id] + node.descendant_ids
        conditions << "archive_node_id IN (#{ids.map { |i| connection.quote(i) }.join(",")})"
      end
    end

    if date_from.present? && date_to.present?
      decade_from = (Date.parse(date_from.to_s).year / 10) * 10
      decade_to = (Date.parse(date_to.to_s).year / 10) * 10
      conditions << "decade >= ? AND decade <= ?"
      binds.push(decade_from, decade_to)
    end

    conditions << "fonds_id IS NOT NULL"
    where_sql = "WHERE #{conditions.join(" AND ")}"

    statement = <<~SQL
      SELECT fonds_name, fonds_id, COUNT(*) AS file_count
      FROM archive_file_trigrams
      #{where_sql}
      GROUP BY fonds_id, fonds_name
      ORDER BY file_count DESC
      LIMIT 10
    SQL

    sql = binds.any? ? sanitize_sql_array([statement, *binds]) : statement
    connection.select_all(sql).to_a
  end

  def self.decade_facets(query, node_id: nil, date_from: nil, date_to: nil)
    conditions = []
    binds = []

    if query.present?
      conditions << "archive_file_trigrams MATCH ?"
      binds << sanitize_fts5(query)
    end

    if node_id.present?
      node = ArchiveNode.find_by(id: node_id)
      if node
        ids = [node.id] + node.descendant_ids
        conditions << "archive_node_id IN (#{ids.map { |i| connection.quote(i) }.join(",")})"
      end
    end

    if date_from.present? && date_to.present?
      decade_from = (Date.parse(date_from.to_s).year / 10) * 10
      decade_to = (Date.parse(date_to.to_s).year / 10) * 10
      conditions << "decade >= ? AND decade <= ?"
      binds.push(decade_from, decade_to)
    end

    conditions << "decade IS NOT NULL"
    where_sql = "WHERE #{conditions.join(" AND ")}"

    statement = <<~SQL
      SELECT decade, COUNT(*) AS file_count
      FROM archive_file_trigrams
      #{where_sql}
      GROUP BY decade
      ORDER BY decade
    SQL

    sql = binds.any? ? sanitize_sql_array([statement, *binds]) : statement
    connection.select_all(sql).to_a
  end
end
