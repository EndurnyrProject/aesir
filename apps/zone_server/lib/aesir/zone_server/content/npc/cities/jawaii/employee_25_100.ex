defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee25100 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Itere.

  ## Behavior

  - Responds to welcome and solo events with different emotions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 25,
        y: 100,
        dir: 0,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnWelcome", ctx), do: emotion(ctx, :chup)
  def on_event("OnSolo", ctx), do: emotion(ctx, :huk)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Employee Itere]") |> mes("Welcome to") |> mes("Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> married_dialogue(ctx)
      not Rathena.truthy?(partner_id) -> single_dialogue(ctx)
      true -> ctx |> mes("I hope you will have a good time.") |> close()
    end
  end

  defp married_dialogue(ctx) do
    ctx
    |> next()
    |> mes("[Employee Itere]")
    |> mes("Oh~")
    |> mes("You look so happy")
    |> mes("to be here with your")
    |> mes("partner! How precious~")
    |> close()
  end

  defp single_dialogue(ctx) do
    ctx
    |> mes("I hope you")
    |> mes("enjoy your st--")
    |> mes("Wait a minute...!")
    |> next()
    |> mes("[Employee Itere]")
    |> mes("You're...")
    |> mes("You better not be part of")
    |> mes("the Invincible Single Army!")
    |> next()
    |> mes("[Employee Itere]")
    |> mes("Well, whatever you do, don't despair, get drunk and then")
    |> mes("bother the married couples!")
    |> close()
  end
end
