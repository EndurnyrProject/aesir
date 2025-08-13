defmodule Aesir.Commons.Banner do
  @moduledoc """
  ASCII banner display for Aesir Ragnarok Online Server
  """

  @banner """
     ▄▄▄       ▓█████   ██████  ██▓ ██▀███  
    ▒████▄     ▓█   ▀ ▒██    ▒ ▓██▒▓██ ▒ ██▒
    ▒██  ▀█▄   ▒███   ░ ▓██▄   ▒██▒▓██ ░▄█ ▒
    ░██▄▄▄▄██  ▒▓█  ▄   ▒   ██▒░██░▒██▀▀█▄  
     ▓█   ▓██▒░▒████▒▒██████▒▒░██░░██▓ ▒██▒
     ▒▒   ▓▒█░░░ ▒░ ░▒ ▒▓▒ ▒ ░░▓  ░ ▒▓ ░▒▓░
      ▒   ▒▒ ░ ░ ░  ░░ ░▒  ░ ░ ▒ ░  ░▒ ░ ▒░
      ░   ▒      ░   ░  ░  ░   ▒ ░  ░░   ░ 
          ░  ░   ░  ░      ░   ░     ░     
  """

  @subtitle "Ragnarok Online Server Emulator"
  @divider "═" |> String.duplicate(60)

  def display(server_type \\ nil) do
    IO.puts("")
    display_banner()
    display_subtitle()
    display_server_info(server_type)
    display_divider()
    IO.puts("")
  end

  defp display_banner do
    @banner
    |> String.split("\n")
    |> Enum.each(fn line ->
      [:cyan, line] |> Bunt.puts()
    end)
  end

  defp display_subtitle do
    IO.puts("")
    [:white, "    ", @subtitle] |> Bunt.puts()
  end

  defp display_server_info(nil), do: :ok

  defp display_server_info(server_type) do
    IO.puts("")
    server_name = format_server_type(server_type)
    [:bright, :yellow, "           ", server_name, " Server"] |> Bunt.puts()
  end

  defp display_divider do
    IO.puts("")
    [:faint, :white, @divider] |> Bunt.puts()
  end

  defp format_server_type(:account), do: "Account"
  defp format_server_type(:char), do: "Character"
  defp format_server_type(:zone), do: "Zone"
end
