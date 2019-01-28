# frozen_string_literal: true

class Repository # as distinct from `Hanami::Repository`
  include Hanami::Utils::ClassAttribute

  class_attribute :entity_name, :relation

  def initialize(*_args, **_params)
    @next_id = 1
    @records = {}
  end

  def create(data)
    extra_attribs = { id: @next_id, created_at: Time.now, updated_at: Time.now }
    attribs = extra_attribs.merge(data.to_h)
    # record = entity_name.new attribs
    record = User.new attribs
    @records[@next_id] = record
    @next_id += 1
    record
  end

  def update(id, data)
    record = find(id)
    return nil unless record
    new_attribs = record.to_h.merge(updated_at: Time.now).merge(data.to_h)
    @records[record.id] = User.new(new_attribs)
  end

  # def delete(id)
  #   @records.delete id
  # end

  def all
    @records.values.sort_by(&:id)
  end

  def find(id)
    @records[id]
  end

  def first
    all.first
  end

  def last
    all.last
  end

  def clear
    @records = {}
  end

  private

  def select(key, value)
    @records.values.select { |other| other.to_h[key] == value }
  end
end
