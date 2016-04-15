defmodule Bamboo.SmtpAdapter do
  @moduledoc """
  Sends email using SMTP.
  """
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  def deliver(email, config) do
    get_domain(config)
  end

  def handle_config(config) do
    if Map.get(config, :domain) do
      config
    else
      raise_domain_error(config)
    end
  end

  defp get_domain(config) do
    case Map.get(config, :domain) do
      nil -> raise_domain_error(config)
      key -> key
    end
  end

  defp raise_domain_error(config) do
    raise ArgumentError, """
    There was no domain set for the Smtp adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

end
