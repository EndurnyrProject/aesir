defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee2594 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Tryteh.

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
        y: 94,
        dir: 0,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw1"
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
    ctx = ctx |> mes("[Employee Tryteh]") |> mes("Welcome to Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> married_dialogue(ctx)
      not Rathena.truthy?(partner_id) -> single_dialogue(ctx)
      true -> ctx |> mes("I hope you will have a good time.") |> close()
    end
  end

  defp married_dialogue(ctx) do
    ctx
    |> mes(
      "Anyway, I am so glad that you two have gotten married. I hope you both will live happily ever after~"
    )
    |> next()
    |> mes("[Employee Tryteh]")
    |> mes("Try to be a little careful if you bump into any rude customers.")
    |> mes("They might be drunk and do something stupid. You know")
    |> mes("how it is...")
    |> close()
  end

  defp single_dialogue(ctx) do
    ctx
    |> mes("I hope you enjoy your stay")
    |> mes("over here. But try not")
    |> mes("to drink too much~")
    |> close()
  end
end
