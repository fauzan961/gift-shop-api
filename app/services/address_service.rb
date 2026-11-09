class AddressService
  MAX_PER_USER = 10

  class LimitReached < StandardError; end

  def create(user, attributes)
    user.with_lock do
      count = user.addresses.count
      ensure_within_limit!(count)

      address = user.addresses.build(attributes)
      address.is_default = true if count.zero?
      save_with_default!(address)
    end
  end

  def update(address, attributes)
    address.user.with_lock do
      address.reload
      address.assign_attributes(attributes)
      address.is_default = true if address.is_default_was

      save_with_default!(address)
    end
  end

  def destroy(address)
    address.user.with_lock do
      address.reload
      address.destroy!
      address.user.addresses.order(:id).first&.update!(is_default: true) if address.is_default?
    end
  end

  private
    def ensure_within_limit!(count)
      raise LimitReached, "You can save up to #{MAX_PER_USER} addresses." if count >= MAX_PER_USER
    end

    def save_with_default!(address)
      address.user.addresses.where(is_default: true).where.not(id: address.id).update_all(is_default: false) if address.is_default?
      address.save!
      address
    end
end
