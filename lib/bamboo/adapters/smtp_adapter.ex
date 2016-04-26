defmodule Bamboo.SmtpAdapter do
  @moduledoc """
  Sends email using SMTP.
  """
  @behaviour Bamboo.Adapter
  @client Application.get_env(:bamboo, :smtp_client)

  alias Bamboo.Email

  def deliver(email, config) do
    get_relay(config)
    format_email(email, config)
    |> @client.send(config)
  end

  def handle_config(config) do
    if Map.get(config, :relay) do
      config
    else
      raise_relay_error(config)
    end
  end

  def format_email(email, config) do
    config = Enum.into(config, [])
    from_address = Email.get_address(email.from)
    {from_address, email.to, email.text_body}
  end

  defp get_relay(config) do
    case Map.get(config, :relay) do
      nil -> raise_relay_error(config)
      key -> key
    end
  end

  defp raise_relay_error(config) do
    raise ArgumentError, """
    There was no relay set for the Smtp adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

end
