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
        conditions << "archive_file_trigrams.archive_node_id IN (#{ids.map { |i| connection.quote(i) }.join(",")})"
      end
    end

    if date_from.present? && date_to.present?
      conditions << "af.source_date_start >= ? AND af.source_date_start < ?"
      binds.push(date_from, date_to)
    end

    where_sql = conditions.any? ? "WHERE #{conditions.join(" AND ")}" : ""

    from_clause =
      if query.present?
        "archive_file_trigrams JOIN archive_files af ON af.id = archive_file_trigrams.archive_file_id"
      else
        "archive_files af"
      end

    statement = <<~SQL
      SELECT json_extract(af.parents, '$[0].name') AS fonds_name,
             CAST(json_extract(af.parents, '$[0].id') AS INTEGER) AS fonds_id,
             COUNT(*) AS file_count
      FROM #{from_clause}
      #{where_sql}
      GROUP BY fonds_name, fonds_id
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
        conditions << "archive_file_trigrams.archive_node_id IN (#{ids.map { |i| connection.quote(i) }.join(",")})"
      end
    end

    if date_from.present? && date_to.present?
      conditions << "af.source_date_start >= ? AND af.source_date_start < ?"
      binds.push(date_from, date_to)
    end

    conditions << "af.source_date_start IS NOT NULL"
    where_sql = "WHERE #{conditions.join(" AND ")}"

    from_clause =
      if query.present?
        "archive_file_trigrams JOIN archive_files af ON af.id = archive_file_trigrams.archive_file_id"
      else
        "archive_files af"
      end

    statement = <<~SQL
      SELECT (CAST(strftime('%Y', af.source_date_start) AS INTEGER) / 10) * 10 AS decade,
             COUNT(*) AS file_count
      FROM #{from_clause}
      #{where_sql}
      GROUP BY decade
      ORDER BY decade
    SQL

    sql = binds.any? ? sanitize_sql_array([statement, *binds]) : statement
    connection.select_all(sql).to_a
  end
end
