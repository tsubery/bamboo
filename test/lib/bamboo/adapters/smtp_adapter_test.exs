defmodule Bamboo.SmtpAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SmtpHelper
  alias Bamboo.SmtpAdapter

  @config %{adapter: SmtpAdapter, relay: "www.example.com"}
  @bad_config %{adapter: SmtpAdapter}

  defmodule FakeSmtp do
    defstruct from: "",
    to: "",
    content: ""

    def start() do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def clear do
      Agent.update(__MODULE__, fn(_state) -> [] end)
    end

    def send({from, to, composed_email}, config) do
      mail_data = %FakeSmtp{
        from: from,
        to: to,
        content: composed_email
      }

      Agent.update(__MODULE__, fn(state) -> [mail_data | state] end)
    end

    def get_mails do
      Agent.get(__MODULE__, fn(state) -> state end)
    end
  end

  setup do
    FakeSmtp.start

    :ok
  end

  test "raises if the relay is nil" do
    assert_raise ArgumentError, ~r/no relay set/, fn ->
      new_email(from: "foo@bar.com") |> SmtpAdapter.deliver(@bad_config)
    end

    assert_raise ArgumentError, ~r/no relay set/, fn ->
      SmtpAdapter.handle_config(%{})
    end
  end

  test "deliver/2 sends an email" do
    new_email |> SmtpAdapter.deliver(@config)

    assert length(FakeSmtp.get_mails) == 1
  end

  test "deliver/2 sends from, html and text body, subject, and headers" do
    email = new_email(
      from: {"From", "from@foo.com"},
      subject: "My Subject",
      text_body: "TEXT BODY",
      html_body: "HTML BODY",
    )
    |> Email.put_header("Reply-To", "reply@foo.com")

    email |> SmtpAdapter.deliver(@config)

    assert length(FakeSmtp.get_mails) == 1
    [sent_email] = FakeSmtp.get_mails
    assert elem(email.from, 1) == sent_email.from

    # assert message["from_name"] == email.from |> elem(0)
    # assert message["from_email"] == email.from |> elem(1)
    # assert message["subject"] == email.subject
    # assert message["text"] == email.text_body
    # assert message["html"] == email.html_body
    # assert message["headers"] == email.headers
  end

  test "deliver/2 correctly formats recipients" do
  end

  test "raises if the response is not a success" do
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end
