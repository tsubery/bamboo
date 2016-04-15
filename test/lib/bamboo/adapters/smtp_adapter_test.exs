defmodule Bamboo.SmtpAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SmtpHelper
  alias Bamboo.SmtpAdapter

  @config %{adapter: SmtpAdapter, domain: "www.example.com"}
  @bad_config %{adapter: SmtpAdapter}

  defmodule FakeSmtp do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :match
    plug :dispatch

    def start_server(parent) do
      Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
      Agent.update(__MODULE__, &HashDict.put(&1, :parent, parent))
      port = get_free_port
      Application.put_env(:bamboo, :smtp_base_uri, "http://localhost:#{port}")
      Plug.Adapters.Cowboy.http __MODULE__, [], port: port, ref: __MODULE__
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/api/1.0/messages/send.json" do
      case get_in(conn.params, ["message", "from_email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> HashDict.get(set, :parent) end)
      send parent, {:fake_smtp, conn}
      conn
    end
  end

  setup do
    FakeSmtp.start_server(self)

    on_exit fn ->
      FakeSmtp.shutdown
    end

    :ok
  end

  test "raises if the domain is nil" do
    assert_raise ArgumentError, ~r/no domain set/, fn ->
      new_email(from: "foo@bar.com") |> SmtpAdapter.deliver(@bad_config)
    end

    assert_raise ArgumentError, ~r/no domain set/, fn ->
      SmtpAdapter.handle_config(%{})
    end
  end

  # test "deliver/2 sends the to the right url" do
  #   new_email |> SmtpAdapter.deliver(@config)
  #
  #   assert_receive {:fake_smtp, %{request_path: request_path}}
  #
  #   assert request_path == "/api/1.0/messages/send.json"
  # end
  #
  # test "deliver/2 sends from, html and text body, subject, and headers" do
  #   email = new_email(
  #     from: {"From", "from@foo.com"},
  #     subject: "My Subject",
  #     text_body: "TEXT BODY",
  #     html_body: "HTML BODY",
  #   )
  #   |> Email.put_header("Reply-To", "reply@foo.com")
  #
  #   email |> SmtpAdapter.deliver(@config)
  #
  #   assert_receive {:fake_smtp, %{params: params}}
  #   assert params["key"] == @config[:api_key]
  #   message = params["message"]
  #   assert message["from_name"] == email.from |> elem(0)
  #   assert message["from_email"] == email.from |> elem(1)
  #   assert message["subject"] == email.subject
  #   assert message["text"] == email.text_body
  #   assert message["html"] == email.html_body
  #   assert message["headers"] == email.headers
  # end
  #
  # test "deliver/2 correctly formats recipients" do
  #   email = new_email(
  #     to: [{"To", "to@bar.com"}],
  #     cc: [{"CC", "cc@bar.com"}],
  #     bcc: [{"BCC", "bcc@bar.com"}],
  #   )
  #
  #   email |> SmtpAdapter.deliver(@config)
  #
  #   assert_receive {:fake_smtp, %{params: %{"message" => message}}}
  #   assert message["to"] == [
  #     %{"name" => "To", "email" => "to@bar.com", "type" => "to"},
  #     %{"name" => "CC", "email" => "cc@bar.com", "type" => "cc"},
  #     %{"name" => "BCC", "email" => "bcc@bar.com", "type" => "bcc"}
  #   ]
  # end
  #
  # test "deliver/2 adds extra params to the message " do
  #   email = new_email |> SmtpHelper.put_param("important", true)
  #
  #   email |> SmtpAdapter.deliver(@config)
  #
  #   assert_receive {:fake_smtp, %{params: %{"message" => message}}}
  #   assert message["important"] == true
  # end
  #
  # test "raises if the response is not a success" do
  #   email = new_email(from: "INVALID_EMAIL")
  #
  #   assert_raise Bamboo.SmtpAdapter.ApiError, fn ->
  #     email |> SmtpAdapter.deliver(@config)
  #   end
  # end
  #
  # test "removes api key from error output" do
  #   email = new_email(from: "INVALID_EMAIL")
  #
  #   assert_raise Bamboo.SmtpAdapter.ApiError, ~r/"key" => "\[FILTERED\]"/, fn ->
  #     email |> SmtpAdapter.deliver(@config)
  #   end
  # end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end
