defmodule FlowerShopWeb.ErrorJSON do
  @moduledoc "Renders Phoenix-level errors (404 for unknown routes, 500) as UCP error documents."

  def render(template, _assigns) do
    Bazaar.Errors.response(Phoenix.Controller.status_message_from_template(template))
  end
end
