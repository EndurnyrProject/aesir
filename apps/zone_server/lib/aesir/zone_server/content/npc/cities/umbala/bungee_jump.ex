defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.BungeeJump do
  @moduledoc """
  Resolves the Umbala bungee jump's random fall outcome.

  ## Behavior

  - On touch, either applies a -100 percent HP effect and announces the jump or removes half the jumper's HP and announces it.
  - A third outcome has an even chance to leave the jumper untouched or reduce HP by 99 percent and warp to Niflheim.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: handle_jump(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp handle_jump(ctx) do
    case Enum.random(1..3) do
      1 ->
        ctx
        |> percent_heal(hp: -100, sp: 0)
        |> mapannounce(
          "umbala",
          "Bungee Jump: #{char_name(ctx, 0)} : Kyaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa~~~~~~~",
          1
        )

      2 ->
        ctx
        |> percent_heal(hp: -50, sp: 0)
        |> mapannounce(
          "umbala",
          "Bungee Jump: #{char_name(ctx, 0)} : Wooooooaaaaaaaaaaaaaahhhhhhhhhhhh~~~~~~!",
          1
        )

      3 ->
        if Enum.random(1..2) == 2 do
          ctx |> percent_heal(hp: -99, sp: 0) |> warp("nif_in", 69, 15)
        else
          ctx
        end

      _ ->
        ctx
    end
  end
end
