---
layout: post
title: "Ruby Hash#fetch and Javascript"
date: 2014-03-06 19:21:15 -0600
comments: true
categories:
  - Intermediate Ruby
  - Javascript
tags: code
image:
  credit: Photo by Mitchell Orr on Unsplash
  feature: /assets/images/hero/mitchell-orr-389605-unsplash.jpg
  topPosition: -200px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: no
author:
  name: Step Aument
convertkit:
  form_uid: 697093712f
  form_url: https://f.convertkit.com/697093712f/34b641aedd.js
---

In a [previous
post](/blog/2014/03/05/the-null-object-pattern-and-method-missing-in-ruby/) I
mentioned a case in which I had a Haml template in a Rails app with Javascript
in it. The template was rendering Ruby values into what would become a JSON
object (Javascript Hash) in the browser. In that particular case, a method call
on a Null Object was returning nil and breaking the Javascript.

Well, today I encountered another variation of this problem. In this case, I
had a Ruby Hash feeding values into the JSON object. It looked like this:

{% highlight ruby linedivs %}
var options = {
  "gender": "#{search_params['gender']}",
  "age": "#{current_user.age}",
  "language": "#{search_params['language']}",
  "query": "#{search_params['query']}",
  "properties": "#{search_params['properties']}"
};
{% endhighlight %}

Two of these fields on the ruby hash are empty: {% ihighlight ruby %}language{% endihighlight %} and {% ihighlight ruby %}properties{% endihighlight %}.
Notice that this isn't a problem for most of these fields, but for one it is:

{% highlight javascript linedivs %}
var options = {
  "gender": "M",
  "age": "27",
  "language": "",
  "query": "specials",                                                                                                                  
  "properties": 
};
{% endhighlight %}

See that? The first four fields feed into double quotes as strings. If they are
empty, they are empty. It may cause an issue somewhere down the line, but the
Javascript itself is valid.

The {% ihighlight ruby %}properties{% endihighlight %} field, on the other hand is expecting a JSON object. That
missing bit will cause Javascript to blow up once this loads in the browser.

What's the solution here? In this case, I turned to {% ihighlight ruby %}Hash#fetch{% endihighlight %} rather than
the {% ihighlight ruby %}[]{% endihighlight %} accessor. What's the difference? There are two main differences
between the bracket accessor and the {% ihighlight ruby %}fetch{% endihighlight %} method. First,
{% ihighlight ruby %}my_hash[:some_missing_key]{% endihighlight %} will return {% ihighlight ruby %}nil{% endihighlight %} if the key is not found in the
hash. If {% ihighlight ruby %}my_hash.fetch(:some_missing_key){% endihighlight %} can't find a key, it will raise a
{% ihighlight ruby %}KeyError{% endihighlight %} exception.

That's not really what we are looking for, which brings me to the second
difference. {% ihighlight ruby %}Hash#fetch{% endihighlight nolines %} takes an optional second argument which specifies a
default value. So if we call {% ihighlight ruby %}my_hash.fetch(:some_missing_key, 'tacos'){% endihighlight %} and
the key is not found in the hash, it will return {% ihighlight ruby %}'tacos'{% endihighlight %} instead of {% ihighlight ruby %}nil{% endihighlight %}.
That's exactly what I needed. I returned an empty JSON object {% ihighlight ruby %}{}{% endihighlight %} as the
default.

{% highlight ruby linedivs %}
var options = {
  "gender": "#{search_params['gender']}",
  "age": "#{current_user.age}",
  "language": "#{search_params['language']}",
  "query": "#{search_params['query']}",
  "properties": #{search_params.fetch('properties', {})}
};
{% endhighlight %}

This degraded nicely in the cases in which I had no {% ihighlight ruby %}properties{% endihighlight %} hash in my
{% ihighlight ruby %}search_params{% endihighlight %} hash.

{% highlight javascript linedivs %}
var options = {
  "gender": "M",
  "age": "27",
  "language": "",
  "query": "specials",                                                                                                            
  "properties": {}
};
{% endhighlight %}

No more broken Javascript.
