class AddressSerializer
  def serialize(address)
    {
      id: address.id,
      addressType: address.address_type,
      address: address.address,
      blockArea: address.block_area,
      city: address.city,
      isDefault: address.is_default
    }
  end
end
