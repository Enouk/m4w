defmodule M4wWeb.Ops.ContactJSON do
  alias M4w.Ops.Contact

  def index(%{contacts: contacts}), do: %{data: Enum.map(contacts, &data/1)}

  def global_index(%{contacts: contacts}) do
    %{
      data:
        Enum.map(contacts, fn c ->
          %{
            name: c.name,
            email: c.email,
            group: c.group,
            roles: c.roles,
            spaces:
              Enum.map(c.spaces, fn s ->
                %{id: to_string(s.id), name: s.name, rooms: s.rooms}
              end)
          }
        end)
    }
  end

  def data(%Contact{} = contact) do
    %{
      id: to_string(contact.id),
      spaceId: to_string(contact.space_id),
      name: contact.name,
      role: contact.role,
      email: contact.email,
      group: contact.kind_group,
      rooms: contact.rooms
    }
  end
end
