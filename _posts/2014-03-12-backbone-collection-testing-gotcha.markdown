---
layout: post
title: "Backbone Collection Testing Gotcha"
date: 2014-03-12 16:46:04 -0500
excerpt: "Be careful of this gotcha when testing a Backbone.js collection."
comments: true
categories:
  - javascript
  - debugging
tags: code
image:
  credit: Photo by Anita Jankovic on Unsplash
  feature: /assets/images/hero/anita-jankovic-730367-unsplash.jpg
  topPosition: -200px
bgContrast: dark
bgGradientOpacity: lighter
syntaxHighlighter: no
author:
  name: Step Aument
---

Be careful of this gotcha when testing a [Backbone.js](http://backbonejs.org/)
collection. I don't have much experience with Backbone, so this is probably
obvious to more experienced users, but hopefully this will help somebody else,
or at least myself in the future.

Today I needed to test the behavior of a Collection with a certain number of
Models in it. I didn't care about the content of the models, just that they
contained a certain field. So, my pair and I came up with this setup to run
in our [Jasmine](http://jasmine.github.io/) specs:

{% highlight javascript linedivs %}
provider = new WellMatch.Models.Provider({display_name: 'a'})
providerArray = (provider for [1..18])
providers = new WellMatch.Collections.Providers(providerArray)
{% endhighlight %}

We created an array of dummy models and passed them into our Collection. This
is one way you can create and populate a Collection. You pass in your array of
models and they become the models in the Collection.

> If that {% ihighlight javascript %}providerArray = (provider for [1..18]){% endihighlight %} syntax freaks you out, don't
> worry. It's just a bit of fancy CoffeeScript and all you need to understand
> for now is that it creates an 18 item array with each element being
> {% ihighlight javascript %}provider{% endihighlight %}.

Makes sense, right? Well, our test failed and when we started debugging in the
browser, here's what we saw:

{% highlight javascript linedivs %}
Providers {fullParams: function, length: 1, models: Array[1], _byId: Object, _events: Object…}
{% endhighlight %}

What??? {% ihighlight javascript %}length: 1, models: Array[1]{% endihighlight %}? When we looked into the models array it
contained a single item from the array we passed in.

Next we tried setting the models array after the fact:

{% highlight javascript linedivs %}
provider = new WellMatch.Models.Provider({display_name: 'a'})
providers = new WellMatch.Collections.Providers()
providers.models = providerArray
{% endhighlight %}

The models array seems right now, but the collection length was still one:

{% highlight javascript linedivs %}
Providers {fullParams: function, length: 1, models: Array[18], _byId: Object, _events: Object…}
{% endhighlight %}

This was just as baffling. By this time we had called in [Tim
Tyrell](@timtyrrell) to tell us what we were doing wrong. Tim had the foresight
to read, not just the docs for the Backbone Collection {% ihighlight javascript %}initializer{% endihighlight %} method, but
also the documentation for the {% ihighlight javascript %}add{% endihighlight %} method, which had this to say (emphasis
added):

> *If you're adding models to the collection that are already in the collection,
> they'll be ignored*, unless you pass {merge: true}, in which case their
> attributes will be merged into the corresponding models, firing any
> appropriate "change" events.

Interesting! When add is called, it ignores any objects that are already
present in the models array. Since we are using the same model instance in each
position of our array, only the first one is being stored. The rest are being
dumped.

A quick check of the [Backbone source
code](https://github.com/jashkenas/backbone/blob/master/backbone.js#L785-L799)
confirms that the initialize method is calling {% ihighlight javascript %}reset{% endihighlight %} with the array you pass
in, which iterates over the array and calls {% ihighlight javascript %}add{% endihighlight %} for each.

{% highlight javascript linedivs %}
/* Excerpt starting at line 785 */

// When you have more items than you want to add or remove individually,
// you can reset the entire set with a new list of models, without firing
// any granular {% ihighlight javascript %}add{% endihighlight %} or {% ihighlight javascript %}remove{% endihighlight %} events. Fires {% ihighlight javascript %}reset{% endihighlight %} when finished.
// Useful for bulk operations and optimizations.
reset: function(models, options) {
  options || (options = {});
  for (var i = 0, length = this.models.length; i < length; i++) {
    this._removeReference(this.models[i], options);
  }
  options.previousModels = this.models;
  this._reset();
  models = this.add(models, _.extend({silent: true}, options));
  if (!options.silent) this.trigger('reset', this, options);
  return models;
},
{% endhighlight %}

So, my pair, Curtis Ekstrom decided to try creating a new object for each
element of the array with the same data to see if that would work.

{% highlight javascript linedivs %}
providerArray = (new WellMatch.Models.Provider(display_name: 'a') for [1..18])
providers = new WellMatch.Collections.Providers(providerArray)
{% endhighlight %}

And so it did. At first I thought that Backbone was performing a simple object
identity check (===) vs an equality check (==). That would make sense of the
behavior we saw, but when I read the {% ihighlight javascript %}add{% endihighlight %} documentation again, I saw that
passing {% ihighlight javascript %}{merge: true}{% endihighlight %} along with the model or model array would result in the
attributes passed in being merged into the existing objects. It must be doing
something else entirely.

Another peek into the [source
code](https://github.com/jashkenas/backbone/blob/master/backbone.js#L718-L728)
confirms. {% ihighlight javascript %}add{% endihighlight %} calls {% ihighlight javascript %}set{% endihighlight %}, which contains the relevant:

{% highlight javascript linedivs %}
/* Except starting at line 718 */

// If a duplicate is found, prevent it from being added and
// optionally merge it into the existing model.
if (existing = this.get(id)) {
  if (remove) modelMap[existing.cid] = true;
  if (merge) {
    attrs = attrs === model ? model.attributes : attrs;
    if (options.parse) attrs = existing.parse(attrs, options);
    existing.set(attrs, options);
    if (sortable && !sort && existing.hasChanged(sortAttr)) sort = true;
  }
  models[i] = existing;
{% endhighlight %}

That first line {% ihighlight javascript %}if (existing = this.get(id)) { {% endihighlight %} is the key. It looks for an
existing model in the {% ihighlight javascript %}_byId{% endihighlight %} object hash, with the same {% ihighlight javascript %}id{% endihighlight %}, {% ihighlight javascript %}cid{% endihighlight %} or that is the
object itself. If it finds it, and {% ihighlight javascript %}merge{% endihighlight %} is not {% ihighlight javascript %}true{% endihighlight %} it rejects the model.

TL;DR - Make sure each Model in the array you pass to the Collection
initializer is a distinct instance, even if the data is otherwise identincal.
