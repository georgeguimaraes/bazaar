defmodule FlowerShopWeb.ErrorJSON do
  @moduledoc "Renders Phoenix-level errors (404 for unknown routes, 500) as UCP error documents."

  def render(template, _assigns) do
    code = template |> Path.rootname() |> then(&"http_#{&1}")

    FlowerShopWeb.Responses.error_document(
      code,
      Phoenix.Controller.status_message_from_template(template)
    )
  end
end
